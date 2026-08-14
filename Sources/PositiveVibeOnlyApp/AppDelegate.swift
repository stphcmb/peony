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
    var onDragChanged: ((CGSize) -> Void)? = nil
    var onDragEnded: (() -> Void)? = nil
    @State private var isVisible = false

    var body: some View {
        FlowerCardView(greeting: greeting, name: name, updateState: updateState,
                       onRefresh: onRefresh, onClose: onClose,
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

    private let panelSize: CGFloat = 640

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = MenuBarIcon.make()
        item.button?.toolTip = "Peony"
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        panel = makePanel()
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

        let saved = SavedQuotesStore.all()
        if !saved.isEmpty {
            let savedItem = NSMenuItem(title: "Saved Quotes", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for quote in saved {
                let preview = quote.text.count > 44
                    ? "\u{201C}\(quote.text.prefix(44))…\u{201D}"
                    : "\u{201C}\(quote.text)\u{201D}"
                let item = NSMenuItem(title: preview, action: #selector(showSavedQuote(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = quote
                submenu.addItem(item)
            }
            savedItem.submenu = submenu
            menu.addItem(savedItem)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Peony", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    /// Reopens the card with a hearted quote in place of today's — the
    /// rest of the card (flower, compliment, prompt) stays today's.
    @objc private func showSavedQuote(_ sender: NSMenuItem) {
        guard let saved = sender.representedObject as? SavedQuote,
              let content = try? ContentStore.load(),
              let base = Selection.greeting(for: content) else { return }
        let greeting = Greeting(
            quote: Quote(text: saved.text, author: saved.author),
            compliment: base.compliment, prompt: base.prompt, flower: base.flower
        )
        showPanel(greeting: greeting)
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
            // Anchor under the status item, matching NSPopover's default
            // placement: horizontally centred on the button, top edge at the
            // button's bottom. The 640pt frame is mostly transparent margin —
            // the bloom's petal tips reach 300pt from centre, per spec. Clamped
            // to the screen's visible frame so a status item near a screen edge
            // (small display, external monitor) can't push most of the card
            // off-screen.
            let buttonFrameInScreen = buttonWindow.convertToScreen(button.frame)
            let screenFrame = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? buttonFrameInScreen
            var originX = buttonFrameInScreen.midX - panelSize / 2
            var originY = buttonFrameInScreen.minY - panelSize
            originX = min(max(originX, screenFrame.minX), screenFrame.maxX - panelSize)
            originY = max(originY, screenFrame.minY)
            panel.setFrameOrigin(NSPoint(x: originX, y: originY))
        }

        panel.orderFrontRegardless()
        installDismissMonitors()
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
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismissPanel()
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
