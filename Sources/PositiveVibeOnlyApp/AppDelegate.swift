import AppKit
import SwiftUI
import PositiveVibeOnlyCore

/// Wraps `FlowerCardView` with the entrance motion from the approved spec:
/// 180ms opacity+scale in (0.94 -> 1), dropped to a plain fast fade when the
/// system's reduce-motion setting is on. The exit fade is driven separately,
/// on the NSPanel itself — see `dismissPanel()`.
private struct AnimatedCardView: View {
    let greeting: Greeting?
    let name: String?
    let reduceMotion: Bool
    @ObservedObject var updateState: UpdateState
    var onRefresh: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil
    var onTogglePin: (() -> Void)? = nil
    var onDragChanged: ((CGSize) -> Void)? = nil
    var onDragEnded: (() -> Void)? = nil
    @State private var isVisible = false

    var body: some View {
        FlowerCardView(greeting: greeting, name: name, updateState: updateState,
                       onRefresh: onRefresh, onClose: onClose, onTogglePin: onTogglePin,
                       onDragChanged: onDragChanged, onDragEnded: onDragEnded)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(reduceMotion ? 1 : (isVisible ? 1 : 0.94))
            .onAppear {
                withAnimation(.easeOut(duration: reduceMotion ? 0.12 : 0.18)) {
                    isVisible = true
                }
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

    private let panelSize: CGFloat = 640
    /// Petal tips reach 300pt from centre, per spec — the rest of the 640pt
    /// frame is transparent margin, so only this much has to stay on screen.
    private let bloomRadius: CGFloat = 300

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = MenuBarIcon.make()
        item.button?.toolTip = "Peony"
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        panel = makePanel()

        LoginItem.applyDefaultForCurrentBundle()
    }

    /// Borderless, transparent, non-activating: the space between petals
    /// shows the desktop through it, and clicking the card never steals
    /// focus from whatever app was frontmost. Not a standard NSPopover —
    /// a popover always draws its own opaque background shape, which would
    /// hide the bloom's die-cut silhouette.
    private func makePanel() -> NSPanel {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelSize, height: panelSize),
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

    private func togglePanel() {
        if panel.isVisible {
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
        let login = NSMenuItem(title: "Start at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Peony", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleLoginItem() {
        LoginItem.setEnabled(!LoginItem.isEnabled)
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
        if panel.isVisible { installDismissMonitors() }
    }

    /// A random draw instead of today's deterministic pick — one-off, the
    /// next plain click shows today's card again.
    @objc private func showSurpriseGreeting() {
        let greeting = (try? ContentStore.load()).flatMap { Selection.randomGreeting(for: $0) }
        showPanel(greeting: greeting)
    }

    private func showPanel(greeting overrideGreeting: Greeting? = nil) {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }

        let content = try? ContentStore.load()
        let greeting = overrideGreeting ?? content.flatMap { Selection.greeting(for: $0) }
        let name = NSFullUserName().components(separatedBy: " ").first
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        UpdateChecker.checkIfDue { [weak self] in self?.updateState.isAvailable = true }

        dragStartOrigin = nil
        let hosting = NSHostingView(rootView: AnimatedCardView(
            greeting: greeting, name: name, reduceMotion: reduceMotion, updateState: updateState,
            onRefresh: { [weak self] in self?.showSurpriseGreeting() },
            onClose: { [weak self] in self?.dismissPanel() },
            onTogglePin: { [weak self] in self?.handlePinToggled() },
            onDragChanged: { [weak self] translation in self?.handleDragChanged(translation) },
            onDragEnded: { [weak self] in self?.handleDragEnded() }
        ))
        hosting.frame = NSRect(x: 0, y: 0, width: panelSize, height: panelSize)
        panel.contentView = hosting
        panel.alphaValue = 1

        // Refreshing in place (the card's ↺ button) must not snap a
        // dragged card back under the status item — only anchor when the
        // panel is actually appearing.
        if !panel.isVisible {
            panel.setFrameOrigin(randomOrigin(on: buttonWindow.screen))
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
            ?? NSRect(x: 0, y: 0, width: panelSize, height: panelSize)
        let inset = bloomRadius + 12
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
        return NSPoint(x: center.x - panelSize / 2, y: center.y - panelSize / 2)
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
        removeDismissMonitors()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        }
    }

    private func installDismissMonitors() {
        removeDismissMonitors() // re-showing an already-visible panel must not stack monitors
        if !keepsCardOnScreen {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.dismissPanel()
            }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                self?.dismissPanel()
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
