import Foundation
import SwiftUI
import PositiveVibeOnlyCore

/// Whether a newer release is known to be available. Observable so the
/// popover can pick up the answer even if the network check is still in
/// flight when the card first appears.
@MainActor
final class UpdateState: ObservableObject {
    @Published var isAvailable = false
}

/// Checks GitHub Releases for a newer version, at most once a day. This is
/// the app's only network call — it fetches nothing but a version tag, and
/// only when the popover is about to open, never in the background.
enum UpdateChecker {
    private static let repo = "stphcmb/peony"
    static let releasesPageURL = URL(string: "https://github.com/\(repo)/releases/latest")!
    // Internal (not private) so SelfUpdater can reuse it for its own fresh,
    // unthrottled GET instead of duplicating the URL.
    static let apiURL = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!

    private static let lastCheckKey = "UpdateChecker.lastCheckDate"
    private static let cachedLatestTagKey = "UpdateChecker.cachedLatestTag"
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    /// The currently running app's version, from the bundle it's running
    /// from — so this compares against what's actually installed, not a
    /// hardcoded string that could drift from reality.
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Calls `onUpdateAvailable` on the main thread if a newer release
    /// exists. Silent no-op on any failure (offline, GitHub down, rate
    /// limited) — a missed update check is never worth interrupting anyone's
    /// day over.
    static func checkIfDue(onUpdateAvailable: @escaping () -> Void) {
        let defaults = UserDefaults.standard

        if let lastCheck = defaults.object(forKey: lastCheckKey) as? Date,
           Date().timeIntervalSince(lastCheck) < checkInterval {
            if let cachedTag = defaults.string(forKey: cachedLatestTagKey),
               VersionCheck.isNewer(latestTag: cachedTag, currentVersion: currentVersion) {
                DispatchQueue.main.async { onUpdateAvailable() }
            }
            return
        }

        var request = URLRequest(url: apiURL)
        request.timeoutInterval = 5
        URLSession.shared.dataTask(with: request) { data, _, _ in
            defaults.set(Date(), forKey: lastCheckKey)
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else { return }
            defaults.set(tag, forKey: cachedLatestTagKey)
            if VersionCheck.isNewer(latestTag: tag, currentVersion: currentVersion) {
                DispatchQueue.main.async { onUpdateAvailable() }
            }
        }.resume()
    }
}
