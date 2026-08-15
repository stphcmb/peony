import AppKit
import Foundation
import PositiveVibeOnlyCore

/// The "Check for Updates…" menu item's flow: a fresh, unthrottled look at
/// the latest GitHub release (unlike UpdateChecker's once-a-day passive
/// check), then — if newer and running from the real install location —
/// downloads, swaps, and relaunches in place. Completion-handler +
/// DispatchQueue.main style throughout, matching UpdateChecker, not
/// async/await.
@MainActor
enum SelfUpdater {
    private static let assetName = "Peony.zip"
    private static let installedAppPath = "/Applications/Peony.app"

    static func run() {
        var request = URLRequest(url: UpdateChecker.apiURL)
        request.timeoutInterval = 10
        URLSession.shared.dataTask(with: request) { data, _, _ in
            DispatchQueue.main.async {
                handleCheckResponse(data: data)
            }
        }.resume()
    }

    private static func handleCheckResponse(data: Data?) {
        // Unlike UpdateChecker's passive daily check, this ran because the
        // user asked — a failed check must say so, not claim "up to date".
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else {
            presentCheckFailed()
            return
        }
        let current = UpdateChecker.currentVersion
        guard VersionCheck.isNewer(latestTag: tag, currentVersion: current) else {
            presentUpToDate()
            return
        }

        // A dev build (e.g. `swift run`) isn't at the path we'd overwrite —
        // self-replacing it would clobber the wrong thing, so just point at
        // the releases page instead of downloading.
        guard Bundle.main.bundlePath == installedAppPath else {
            NSWorkspace.shared.open(UpdateChecker.releasesPageURL)
            return
        }

        let assets = json["assets"] as? [[String: Any]] ?? []
        let downloadURL = assets
            .first { ($0["name"] as? String) == assetName }
            .flatMap { $0["browser_download_url"] as? String }
            .flatMap(URL.init(string:))

        presentUpdateAvailable(tag: tag, current: current, downloadURL: downloadURL)
    }

    // MARK: - Alerts

    private static func presentUpToDate() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "You're up to date"
        alert.informativeText = "Peony v\(UpdateChecker.currentVersion) is the latest version."
        alert.runModal()
    }

    private static func presentCheckFailed() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Couldn't check for updates"
        alert.informativeText = "GitHub couldn't be reached. Check your connection and try again."
        alert.runModal()
    }

    private static func presentUpdateAvailable(tag: String, current: String, downloadURL: URL?) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Peony \(tag) is available — you have v\(current)."
        alert.addButton(withTitle: "Update Now")
        alert.addButton(withTitle: "Later")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        guard let downloadURL else {
            presentFailure(reason: "Couldn't find \(assetName) in the release's assets.")
            return
        }
        downloadAndInstall(from: downloadURL)
    }

    private static func presentFailure(reason: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Update failed"
        alert.informativeText = reason
        alert.addButton(withTitle: "Download Manually")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(UpdateChecker.releasesPageURL)
        }
    }

    // MARK: - Download, extract, swap, relaunch

    private static func downloadAndInstall(from url: URL) {
        let workDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        } catch {
            presentFailure(reason: "Couldn't create a temporary folder: \(error.localizedDescription)")
            return
        }

        let zipPath = workDir.appendingPathComponent(assetName)
        URLSession.shared.downloadTask(with: url) { tempURL, _, error in
            DispatchQueue.main.async {
                guard let tempURL, error == nil else {
                    presentFailure(reason: "Couldn't download the update: \(error?.localizedDescription ?? "unknown error").")
                    return
                }
                do {
                    // downloadTask's file is deleted the moment this closure
                    // returns — move it out before touching it further.
                    try FileManager.default.moveItem(at: tempURL, to: zipPath)
                } catch {
                    presentFailure(reason: "Couldn't save the downloaded update: \(error.localizedDescription)")
                    return
                }
                extractAndSwap(zipPath: zipPath, workDir: workDir)
            }
        }.resume()
    }

    private static func extractAndSwap(zipPath: URL, workDir: URL) {
        do {
            // ditto (not Foundation's zip-less APIs) so the app bundle's
            // symlinks and permissions survive extraction.
            try runProcess("/usr/bin/ditto", ["-xk", zipPath.path, workDir.path])
        } catch {
            presentFailure(reason: "Couldn't unpack the update: \(error.localizedDescription)")
            return
        }

        guard let newApp = locateApp(in: workDir) else {
            presentFailure(reason: "The downloaded update didn't contain Peony.app.")
            return
        }

        // Only remove the installed copy right before the replacement lands
        // — never leave /Applications without a working Peony.app in
        // between. If the copy itself fails, the user needs a manual
        // reinstall, not a silent retry.
        do {
            if FileManager.default.fileExists(atPath: installedAppPath) {
                try FileManager.default.removeItem(atPath: installedAppPath)
            }
            try runProcess("/usr/bin/ditto", [newApp.path, installedAppPath])
        } catch {
            presentFailure(reason: "Couldn't install the update — please reinstall from the releases page. (\(error.localizedDescription))")
            return
        }

        // Ad-hoc signed app, downloaded zip: same quarantine-clearing step
        // install.sh does, or the relaunch below hits a "damaged app" dialog.
        try? runProcess("/usr/bin/xattr", ["-dr", "com.apple.quarantine", installedAppPath])

        relaunch()
    }

    /// `Peony.app` lands either at the extracted dir's top level or one
    /// level down, depending on how the release zip was built.
    private static func locateApp(in dir: URL) -> URL? {
        let fm = FileManager.default
        let direct = dir.appendingPathComponent("Peony.app")
        if fm.fileExists(atPath: direct.path) { return direct }
        guard let children = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return nil }
        for child in children {
            let nested = child.appendingPathComponent("Peony.app")
            if fm.fileExists(atPath: nested.path) { return nested }
        }
        return nil
    }

    private static func relaunch() {
        // Detached, not waited on: this process is about to terminate, so a
        // short sleep gives it time to fully exit before `open` launches the
        // freshly installed copy.
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/bash")
        relaunch.arguments = ["-c", "sleep 1; open '\(installedAppPath)'"]
        try? relaunch.run()
        NSApp.terminate(nil)
    }

    private static func runProcess(_ path: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let reason = output.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: "SelfUpdater", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: reason.isEmpty ? "\((path as NSString).lastPathComponent) failed" : reason
            ])
        }
    }
}
