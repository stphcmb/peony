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
    @State private var isVisible = false

    var body: some View {
        FlowerCardView(greeting: greeting, name: name)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(reduceMotion ? 1 : (isVisible ? 1 : 0.94))
            .onAppear {
                withAnimation(.easeOut(duration: reduceMotion ? 0.12 : 0.18)) {
                    isVisible = true
                }
            }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var outsideClickMonitor: Any?
    private var keyMonitor: Any?

    private let panelSize: CGFloat = 640

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = MenuBarIcon.make()
        item.button?.toolTip = "Flowers"
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
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

    @objc private func togglePanel() {
        if panel.isVisible {
            dismissPanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }

        let content = try? ContentStore.load()
        let greeting = content.flatMap { Selection.greeting(for: $0) }
        let name = NSFullUserName().components(separatedBy: " ").first
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        let hosting = NSHostingView(rootView: AnimatedCardView(greeting: greeting, name: name, reduceMotion: reduceMotion))
        hosting.frame = NSRect(x: 0, y: 0, width: panelSize, height: panelSize)
        panel.contentView = hosting
        panel.alphaValue = 1

        // Anchor under the status item, matching NSPopover's default
        // placement: horizontally centred on the button, top edge at the
        // button's bottom. The 640pt frame is mostly transparent margin —
        // the bloom's petal tips reach 300pt from centre, per spec.
        let buttonFrameInScreen = buttonWindow.convertToScreen(button.frame)
        let originX = buttonFrameInScreen.midX - panelSize / 2
        let originY = buttonFrameInScreen.minY - panelSize
        panel.setFrameOrigin(NSPoint(x: originX, y: originY))

        panel.orderFrontRegardless()
        installDismissMonitors()
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
