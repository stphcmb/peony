import AppKit
import ServiceManagement

/// Start at login, owned by the app rather than the installer: install.sh's
/// LaunchAgent only ever covered the script route, so anyone who downloaded
/// the zip had to reopen Peony by hand after every restart. SMAppService
/// (macOS 13+) registers the whole app bundle, and the same switch shows up
/// in System Settings > General > Login Items — `status` reads that back, so
/// the menu checkmark stays honest if the user flips it there.
enum LoginItem {
    private static let appliedPathKey = "LoginItemDefaultAppliedForPath"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Registering while already registered throws on some macOS versions,
    /// hence the status guards rather than a blind call.
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                guard SMAppService.mainApp.status != .enabled else { return }
                try SMAppService.mainApp.register()
            } else {
                guard SMAppService.mainApp.status == .enabled else { return }
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Peony: login item \(enabled ? "register" : "unregister") failed: \(error.localizedDescription)")
        }
    }

    /// On by default, applied once per bundle location: a menu bar flower is
    /// only ever seen if it's already running. Recording the path rather than
    /// a plain "done" flag is what makes a reinstall or a move work — the old
    /// registration still points at the old bundle, so the default has to be
    /// re-armed for the new one. Within one location it stays a one-shot:
    /// turning it off (here or in System Settings) is never overridden.
    static func applyDefaultForCurrentBundle() {
        let path = Bundle.main.bundlePath
        guard UserDefaults.standard.string(forKey: appliedPathKey) != path else { return }
        UserDefaults.standard.set(path, forKey: appliedPathKey)
        setEnabled(true)
    }
}
