import Foundation

public enum VersionCheck {
    /// True when `latestTag` (e.g. "v1.0.1" or "1.0.1") is a newer version
    /// than `currentVersion` (e.g. "1.0.1"). Compares dot-separated numeric
    /// components left to right; a missing trailing component counts as 0,
    /// so "1.1" is newer than "1.0.5". Malformed input (non-numeric parts)
    /// is treated as "not newer" — never nag about a version we can't
    /// actually compare.
    public static func isNewer(latestTag: String, currentVersion: String) -> Bool {
        let latest = parse(latestTag)
        let current = parse(currentVersion)
        guard let latest, let current else { return false }

        for i in 0..<max(latest.count, current.count) {
            let l = i < latest.count ? latest[i] : 0
            let c = i < current.count ? current[i] : 0
            if l != c { return l > c }
        }
        return false
    }

    private static func parse(_ raw: String) -> [Int]? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        guard !s.isEmpty else { return nil }
        let parts = s.split(separator: ".").map { Int($0) }
        guard parts.allSatisfy({ $0 != nil }) else { return nil }
        return parts.map { $0! }
    }
}
