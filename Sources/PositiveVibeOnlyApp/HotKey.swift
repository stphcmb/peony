import Carbon.HIToolbox

/// A global keyboard shortcut, ⌃⌥⌘P (P for Peony) — built on the old Carbon
/// `RegisterEventHotKey` API rather than an `NSEvent` global monitor.
/// A global monitor needs Accessibility permission (a whole System Settings
/// detour for a menu-bar toy) and only observes the keypress, it can't
/// consume it, so the shortcut would leak through to whatever app is
/// frontmost. Carbon's hotkey API needs no permission and eats the event
/// outright — deprecated for two decades, still the only free way to do
/// this on macOS.
///
/// The combo is hardcoded, not a setting: this exists so the card has a
/// door that isn't the menu bar icon (which macOS can squeeze out of a full
/// bar), and there's no evidence yet that anyone needs to change it.
@MainActor
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let onPress: () -> Void

    /// Four-char signature Carbon wants for hotkey IDs — arbitrary, just
    /// needs to not collide with another app's, which "PeoH" won't.
    private static let signature: OSType = {
        let chars = Array("PeoH".utf8CString)
        return (OSType(chars[0]) << 24) | (OSType(chars[1]) << 16) | (OSType(chars[2]) << 8) | OSType(chars[3])
    }()

    /// Fails (returns nil) if either Carbon call errs — a missing hotkey
    /// must never crash the app, it just means that door stays closed and
    /// the menu bar icon remains the only way in.
    init?(onPress: @escaping () -> Void) {
        self.onPress = onPress

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var handlerRef: EventHandlerRef?
        // The handler must be a capture-free C function pointer, so it can't
        // reach `self` directly — the registration below passes `self` in as
        // opaque userData instead, unwrapped back into a HotKey here.
        let installStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_: EventHandlerCallRef?, _: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in hotKey.onPress() }
                return noErr
            },
            1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        guard installStatus == noErr else { return nil }
        eventHandler = handlerRef

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        var ref: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_P),
            UInt32(controlKey | optionKey | cmdKey),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        guard registerStatus == noErr, let ref else {
            if let eventHandler { RemoveEventHandler(eventHandler) }
            return nil
        }
        hotKeyRef = ref
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
