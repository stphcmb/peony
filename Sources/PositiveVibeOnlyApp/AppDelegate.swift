import AppKit
import CoreGraphics
import SwiftUI
import PositiveVibeOnlyCore

/// Wraps either card (greeting or break) with the entrance motion from the
/// approved spec: 180ms opacity fade plus a springy scale+rotation pop,
/// dropped to a plain fast fade when the system's reduce-motion setting is
/// on. Generic so the break card gets exactly the same entrance as the
/// greeting card, not a re-tuned copy. The exit fade is driven separately,
/// on the NSPanel itself — see `dismissPanel()`.
private struct AnimatedEntrance<Content: View>: View {
    let reduceMotion: Bool
    @ViewBuilder let content: Content
    @State private var isVisible = false

    var body: some View {
        content
            .opacity(isVisible ? 1 : 0)
            .animation(.easeOut(duration: reduceMotion ? 0.12 : 0.18), value: isVisible)
            // A separate .animation() boundary so the pop (scale+rotation)
            // can run on its own spring curve instead of the fade's easeOut.
            .scaleEffect(reduceMotion ? 1 : (isVisible ? 1 : 0.4))
            .rotationEffect(reduceMotion ? .zero : .degrees(isVisible ? 0 : -5))
            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.65), value: isVisible)
            .onAppear {
                isVisible = true
            }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var outsideClickMonitor: Any?
    private var keyMonitor: Any?
    private let updateState = UpdateState()
    private var dragStartOrigin: NSPoint?
    private var lastCenter: NSPoint?
    private var hourlyTimer: Timer?
    private var autoFadeWork: DispatchWorkItem?
    private var lastHourSlot = -1
    private var hotKey: HotKey?

    private var currentGreeting: Greeting?
    private var breakClock = BreakClock()
    private var breakTimer: Timer?
    // Which of the two card types is currently in the panel — the pin/close
    // gestures and the hourly-bloom suppression both need to know.
    private var isShowingBreakCard = false
    private var lastBreakFireDate: Date?
    private let breakTickInterval: TimeInterval = 30
    /// Six hours: often enough that a release reaches everyone the same
    /// day, rare enough that a laptop lid opened for five minutes doesn't
    /// spend that time talking to GitHub.
    private static let autoUpdateInterval: TimeInterval = 6 * 60 * 60

    private let scaleState = CardScaleState()
    private let panelSize: CGFloat = CardScaleState.baseSize
    /// Petal tips reach 300pt from centre, per spec — the rest of the 640pt
    /// frame is transparent margin, so only this much has to stay on screen.
    private let bloomRadius: CGFloat = 300
    /// What the panel actually measures right now: the authored size times
    /// the user's card scale.
    private var scaledPanelSize: CGFloat { panelSize * scaleState.scale }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = MenuBarIcon.make()
        item.button?.toolTip = "Peony"
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        panel = makePanel()
        // SwiftUI can resize its own content but not the window hosting
        // it, so a size change has to come back out here.
        scaleState.onChange = { [weak self] _ in self?.resizePanelToScale() }

        LoginItem.applyDefaultForCurrentBundle()

        // Same semantics as clicking the icon: the icon can vanish from a
        // full menu bar, so this is a second door to the card, not a
        // different behavior.
        hotKey = HotKey { [weak self] in self?.togglePanel() }

        // Hourly bloom. A 60s check beats a 3600s timer here: after sleep a
        // long timer just drifts, while this notices the changed hour within
        // a minute of waking.
        UserDefaults.standard.register(defaults: [
            "HourlyBloom": true, "BreakReminders": true, "AutoUpdate": true,
        ])
        lastHourSlot = Self.currentHourSlot()
        let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.hourlyTick()
                self?.autoUpdateTick()
            }
        }
        timer.tolerance = 5
        hourlyTimer = timer

        // Same 30s-tick pattern as the hourly timer; BreakClock does the
        // actual state tracking, this just feeds it idle time.
        let breakTimer = Timer.scheduledTimer(withTimeInterval: breakTickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.activityTick() }
        }
        breakTimer.tolerance = 5
        self.breakTimer = breakTimer
    }

    private static func currentHourSlot(calendar: Calendar = .current) -> Int {
        let now = Date()
        let day = calendar.ordinality(of: .day, in: .era, for: now) ?? 0
        return day * 24 + calendar.component(.hour, from: now)
    }

    private var hourlyBloomEnabled: Bool {
        UserDefaults.standard.bool(forKey: "HourlyBloom")
    }

    @objc private func toggleHourlyBloom() {
        UserDefaults.standard.set(!hourlyBloomEnabled, forKey: "HourlyBloom")
    }

    /// On the turn of the hour: a visible card (pinned or not) refreshes in
    /// place to the new hour's pick; a hidden card blooms on its own and
    /// fades after 20s — unless the user pinned it, dragged it, or turned
    /// "Bloom Every Hour" off. A break card in either position is left
    /// alone: never clobber it with the ambient bloom, and never pop the
    /// ambient bloom right on top of (or right after) a break card.
    private func hourlyTick() {
        let slot = Self.currentHourSlot()
        guard slot != lastHourSlot else { return }
        lastHourSlot = slot
        if panel.isVisible {
            guard !isShowingBreakCard else { return }
            showPanel()
        } else if hourlyBloomEnabled, !breakSuppressesAmbientBloom {
            showPanel()
            scheduleAutoFade()
        }
    }

    private var autoUpdateEnabled: Bool {
        UserDefaults.standard.bool(forKey: "AutoUpdate")
    }

    @objc private func toggleAutoUpdate() {
        UserDefaults.standard.set(!autoUpdateEnabled, forKey: "AutoUpdate")
    }

    /// Keeps everyone on the newest Peony without anyone having to know
    /// there is a newer Peony. Most people who run this will never open the
    /// right-click menu, so an update that waits to be asked for is an
    /// update they never get.
    ///
    /// Never while the card is on screen: installing ends in a relaunch, and
    /// a card vanishing mid-read is exactly the interruption this app exists
    /// not to be. Off-screen, the relaunch is invisible — the menu bar icon
    /// blinks and that's all.
    private func autoUpdateTick() {
        guard autoUpdateEnabled, !panel.isVisible else { return }
        let defaults = UserDefaults.standard
        let key = "AutoUpdate.lastCheck"
        if let last = defaults.object(forKey: key) as? Date,
           Date().timeIntervalSince(last) < Self.autoUpdateInterval { return }
        defaults.set(Date(), forKey: key)
        SelfUpdater.runInBackground()
    }

    private var breakRemindersEnabled: Bool {
        UserDefaults.standard.bool(forKey: "BreakReminders")
    }

    @objc private func toggleBreakReminders() {
        UserDefaults.standard.set(!breakRemindersEnabled, forKey: "BreakReminders")
    }

    /// True for 10 minutes after a break last fired — keeps the hourly
    /// ambient bloom from popping up right on top of, or right after
    /// dismissing, a break card. Never two popups within a minute of
    /// each other.
    private var breakSuppressesAmbientBloom: Bool {
        guard let lastBreakFireDate else { return false }
        return Date().timeIntervalSince(lastBreakFireDate) < 10 * 60
    }

    /// 30s cadence: reads system idle time via CGEventSource (no
    /// accessibility or screen-recording permission needed — this API is
    /// free) and feeds BreakClock a tick. The timer itself never stops;
    /// turning "Break Reminders" off just makes each tick a no-op, so
    /// re-enabling it doesn't need a relaunch.
    private func activityTick() {
        guard breakRemindersEnabled else { return }
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
        let event = breakClock.tick(idleSeconds: idle, interval: breakTickInterval)

        // Walking away while the break card is up: BreakClock already
        // cleared its own state above (idle >= 5min always resets it) —
        // take the card down to match, rather than leaving a nudge nobody's
        // there to see.
        if isShowingBreakCard, idle >= 300 {
            dismissPanel()
            return
        }

        if event == .breakDue {
            lastBreakFireDate = Date()
            showBreakCard()
        }
    }

    /// Shows the break card: a random careNudge (a one-off draw, like
    /// Surprise Me) paired with the hour's flower — not a random one, so
    /// the bloom still matches whatever the greeting card would show right
    /// now. Silently does nothing if content failed to load or ships no
    /// nudges — a missed break reminder is never worth a broken card over.
    private func showBreakCard() {
        guard let content = try? ContentStore.load(), let nudge = content.careNudges.randomElement() else { return }
        let flower = Selection.greeting(for: content)?.flower
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        // A squeezed-out-of-the-menu-bar icon has no window to anchor a
        // fresh show under — randomOrigin already falls back to the main
        // screen when this is nil.
        let screen = statusItem.button?.window?.screen ?? NSScreen.main

        autoFadeWork?.cancel()
        autoFadeWork = nil
        dragStartOrigin = nil

        let toastText = BreakToasts.pick()
        let hosting = NSHostingView(rootView: AnimatedEntrance(reduceMotion: reduceMotion) {
            BreakCardView(
                nudge: nudge, flower: flower, toastText: toastText, scaleState: scaleState,
                onTookIt: { [weak self] in self?.acknowledgeBreakAndDismiss() },
                onSnooze: { [weak self] in self?.snoozeBreakShortAndDismiss() },
                onClose: { [weak self] in self?.snoozeBreakAndDismiss() }
            )
        })
        hosting.frame = NSRect(x: 0, y: 0, width: scaledPanelSize, height: scaledPanelSize)
        // So changing size only has to resize the panel — the hosting view
        // follows it instead of being re-framed separately.
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.alphaValue = 1
        isShowingBreakCard = true

        if !panel.isVisible {
            panel.setFrameOrigin(randomOrigin(on: screen))
        }

        panel.orderFrontRegardless()
        installDismissMonitors(isBreakCard: true)
    }

    /// "Took it ✓" — counts as the real thing, clock restarts from zero.
    private func acknowledgeBreakAndDismiss() {
        breakClock.acknowledge()
        dismissPanel()
    }

    /// "5 more minutes".
    private func snoozeBreakShortAndDismiss() {
        breakClock.snooze(for: 300)
        dismissPanel()
    }

    /// Esc or × on the break card — same longer snooze either way:
    /// dismissal without punishment, but the card returns while the streak
    /// continues.
    private func snoozeBreakAndDismiss() {
        breakClock.snooze(for: 600)
        dismissPanel()
    }

    private func scheduleAutoFade() {
        autoFadeWork?.cancel()
        let work = DispatchWorkItem {
            Task { @MainActor [weak self] in
                guard let self, !self.keepsCardOnScreen else { return }
                self.dismissPanel()
            }
        }
        autoFadeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: work)
    }

    /// Borderless, transparent, non-activating: the space between petals
    /// shows the desktop through it, and clicking the card never steals
    /// focus from whatever app was frontmost. Not a standard NSPopover —
    /// a popover always draws its own opaque background shape, which would
    /// hide the bloom's die-cut silhouette.
    private func makePanel() -> NSPanel {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: scaledPanelSize, height: scaledPanelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .popUpMenu
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        p.isMovable = false
        p.hidesOnDeactivate = false
        return p
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            togglePanel()
        }
    }

    /// A visible break card is never toggled closed by the icon — a
    /// user-opened greeting replaces it instead (the break clock keeps
    /// counting either way); only a visible greeting card toggles shut.
    private func togglePanel() {
        if panel.isVisible && !isShowingBreakCard {
            dismissPanel()
        } else {
            showPanel()
        }
    }

    /// Right-click menu. Built fresh per click and assigned to the status
    /// item only for the duration of `performClick` — a permanently
    /// assigned `statusItem.menu` would swallow left clicks too, and the
    /// card (not a menu) is the left click's job.
    private func showMenu() {
        if panel.isVisible {
            removeDismissMonitors()
            panel.orderOut(nil)
        }
        let menu = NSMenu()
        let surprise = NSMenuItem(title: "Surprise Me", action: #selector(showSurpriseGreeting), keyEquivalent: "")
        surprise.target = self
        menu.addItem(surprise)
        menu.addItem(.separator())
        menu.addItem(cardSizeMenuItem())
        menu.addItem(.separator())
        let hourly = NSMenuItem(title: "Bloom Every Hour", action: #selector(toggleHourlyBloom), keyEquivalent: "")
        hourly.target = self
        hourly.state = hourlyBloomEnabled ? .on : .off
        menu.addItem(hourly)
        let breakReminders = NSMenuItem(title: "Break Reminders", action: #selector(toggleBreakReminders), keyEquivalent: "")
        breakReminders.target = self
        breakReminders.state = breakRemindersEnabled ? .on : .off
        menu.addItem(breakReminders)
        let login = NSMenuItem(title: "Start at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)
        let autoUpdate = NSMenuItem(title: "Update Automatically", action: #selector(toggleAutoUpdate), keyEquivalent: "")
        autoUpdate.target = self
        autoUpdate.state = autoUpdateEnabled ? .on : .off
        menu.addItem(autoUpdate)
        let update = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        update.target = self
        menu.addItem(update)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Peony", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    /// Three named sizes — the whole of resizing. A borderless card has no
    /// window frame to drag, and every gesture tried in its place (corner
    /// grip, edge drag) read as fiddly on something meant to be glanced at,
    /// so the size is a choice made once in the menu, not a manipulation.
    private func cardSizeMenuItem() -> NSMenuItem {
        let sizes: [(String, CGFloat)] = [("Small", 0.8), ("Medium", 1.0), ("Large", 1.3)]
        let submenu = NSMenu()
        for (title, value) in sizes {
            let item = NSMenuItem(title: title, action: #selector(setCardSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = Double(value)
            // Tolerant compare: these are floats round-tripped through
            // UserDefaults, not identities.
            item.state = abs(scaleState.scale - value) < 0.02 ? .on : .off
            submenu.addItem(item)
        }
        let parent = NSMenuItem(title: "Card Size", action: nil, keyEquivalent: "")
        parent.submenu = submenu
        return parent
    }

    @objc private func setCardSize(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        scaleState.scale = CardScaleState.clamped(CGFloat(value))
    }

    @objc private func toggleLoginItem() {
        LoginItem.setEnabled(!LoginItem.isEnabled)
    }

    @objc private func checkForUpdates() {
        SelfUpdater.run()
    }

    /// Mirrors the card's pin button (@AppStorage writes the same key).
    /// When on, the card ignores clicks in other apps and stays up until
    /// explicitly closed (×, Esc, or the menu bar icon). The panel is
    /// non-activating, so it never steals focus while it sits there.
    private var keepsCardOnScreen: Bool {
        UserDefaults.standard.bool(forKey: "KeepCardOnScreen")
    }

    /// Called after the card's pin button has already flipped the stored
    /// value — re-derive the monitors so the change applies immediately,
    /// not just on the next show.
    private func handlePinToggled() {
        if panel.isVisible { installDismissMonitors(isBreakCard: isShowingBreakCard) }
    }

    /// A random draw instead of today's deterministic pick — one-off, the
    /// next plain click shows today's card again.
    @objc private func showSurpriseGreeting() {
        let greeting = (try? ContentStore.load()).flatMap { Selection.randomGreeting(for: $0, avoiding: currentGreeting) }
        showPanel(greeting: greeting)
    }

    private func showPanel(greeting overrideGreeting: Greeting? = nil) {
        // A squeezed-out-of-the-menu-bar icon has no window to anchor a
        // fresh show under — randomOrigin already falls back to the main
        // screen when this is nil. Must not bail out here: the hotkey is
        // exactly the rescue for a hidden icon, so it can't depend on the
        // icon still having a window.
        let screen = statusItem.button?.window?.screen ?? NSScreen.main

        // Any fresh show supersedes a pending auto-fade; the hourly tick
        // re-schedules its own right after this call.
        autoFadeWork?.cancel()
        autoFadeWork = nil

        let content = try? ContentStore.load()
        let greeting = overrideGreeting ?? content.flatMap { Selection.greeting(for: $0) }
        // Remembered so the next "Surprise Me" can avoid dealing the exact
        // same quote/prompt/flower again — see Selection.randomGreeting.
        currentGreeting = greeting
        let name = NSFullUserName().components(separatedBy: " ").first
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        UpdateChecker.checkIfDue { [weak self] in self?.updateState.isAvailable = true }

        dragStartOrigin = nil
        isShowingBreakCard = false
        // Drawn once per show, not in FlowerCardView's body, so it doesn't
        // redraw on every body re-evaluation while the card is up.
        let toastText = GiftNotes.pick(name: name, flower: greeting?.flower?.name)
        let hosting = NSHostingView(rootView: AnimatedEntrance(reduceMotion: reduceMotion) {
            FlowerCardView(greeting: greeting, name: name, toastText: toastText, updateState: updateState,
                           scaleState: scaleState,
                           onRefresh: { [weak self] in self?.showSurpriseGreeting() },
                           onClose: { [weak self] in self?.dismissPanel() },
                           onTogglePin: { [weak self] in self?.handlePinToggled() },
                           onDragChanged: { [weak self] translation in self?.handleDragChanged(translation) },
                           onDragEnded: { [weak self] in self?.handleDragEnded() })
        })
        hosting.frame = NSRect(x: 0, y: 0, width: scaledPanelSize, height: scaledPanelSize)
        // So changing size only has to resize the panel — the hosting view
        // follows it instead of being re-framed separately.
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.alphaValue = 1

        // Refreshing in place (the card's ↺ button) must not snap a
        // dragged card back under the status item — only anchor when the
        // panel is actually appearing.
        if !panel.isVisible {
            panel.setFrameOrigin(randomOrigin(on: screen))
        }

        panel.orderFrontRegardless()
        installDismissMonitors()
    }

    /// The bloom lands somewhere different every time it opens — it's a small
    /// surprise, not a menu, so it doesn't anchor under the status item. The
    /// draw is over bloom *centres* inside the screen's visible frame (which
    /// already excludes the menu bar and Dock), inset by the bloom radius so
    /// no petal falls off an edge. A draw too close to the previous one is
    /// redrawn — pure uniform picks cluster often enough to read as "stuck".
    private func randomOrigin(on screen: NSScreen?) -> NSPoint {
        let frame = (screen ?? NSScreen.main)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: scaledPanelSize, height: scaledPanelSize)
        let inset = bloomRadius * scaleState.scale + 12
        let xRange = (frame.minX + inset)...(max(frame.maxX - inset, frame.minX + inset))
        let yRange = (frame.minY + inset)...(max(frame.maxY - inset, frame.minY + inset))
        // A screen too small to move around in leaves both ranges empty —
        // then every draw is the same centred point, which is the right answer.
        let minMove = min(frame.width, frame.height) / 4

        var center = NSPoint(x: .random(in: xRange), y: .random(in: yRange))
        for _ in 0..<8 {
            guard let last = lastCenter else { break }
            if hypot(center.x - last.x, center.y - last.y) >= minMove { break }
            center = NSPoint(x: .random(in: xRange), y: .random(in: yRange))
        }
        lastCenter = center
        return NSPoint(x: center.x - scaledPanelSize / 2, y: center.y - scaledPanelSize / 2)
    }

    /// Grows and shrinks the panel around the card's own centre, so a Card
    /// Size pick never walks a card the user has already dragged somewhere
    /// across the screen.
    private func resizePanelToScale() {
        let size = scaledPanelSize
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        panel.setFrame(NSRect(x: center.x - size / 2, y: center.y - size / 2,
                              width: size, height: size),
                       display: true)
    }

    /// Drives dragging manually instead of `isMovableByWindowBackground`,
    /// which never fires here — the SwiftUI content covers the whole
    /// window, so AppKit sees no exposed "background" to grab. SwiftUI's
    /// `DragGesture` gives translation cumulative from drag start, so the
    /// origin is captured once (on the first change) and every subsequent
    /// frame sets the window relative to that fixed start, not the last
    /// frame — accumulating deltas frame-over-frame would drift.
    private func handleDragChanged(_ translation: CGSize) {
        if dragStartOrigin == nil {
            dragStartOrigin = panel.frame.origin
            // Dragging means the user wants the card where they put it —
            // an auto-bloomed card must not fade out from under them.
            autoFadeWork?.cancel()
            autoFadeWork = nil
        }
        guard let start = dragStartOrigin else { return }
        // SwiftUI's y grows downward; AppKit's window origin y grows upward.
        let newOrigin = NSPoint(x: start.x + translation.width, y: start.y - translation.height)
        panel.setFrameOrigin(newOrigin)
    }

    private func handleDragEnded() {
        dragStartOrigin = nil
    }

    private func dismissPanel() {
        autoFadeWork?.cancel()
        autoFadeWork = nil
        removeDismissMonitors()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
            self?.isShowingBreakCard = false
        }
    }

    /// A break card ignores outside clicks unconditionally (the pin-mode
    /// monitor path, regardless of the user's actual pin setting) and
    /// treats Esc as a longer snooze instead of a plain dismiss.
    private func installDismissMonitors(isBreakCard: Bool = false) {
        removeDismissMonitors() // re-showing an already-visible panel must not stack monitors
        if !isBreakCard && !keepsCardOnScreen {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.dismissPanel()
            }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                if isBreakCard {
                    self?.snoozeBreakAndDismiss()
                } else {
                    self?.dismissPanel()
                }
                return nil
            }
            return event
        }
    }

    private func removeDismissMonitors() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        outsideClickMonitor = nil
        keyMonitor = nil
    }
}
