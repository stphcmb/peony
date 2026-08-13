import Foundation
import PositiveVibeOnlyCore

enum ContentStore {
    /// Loads the bundled content.json. This ships inside the .app, so it
    /// always succeeds for a correctly built bundle — a throw here means the
    /// build is broken, not that the user did something wrong.
    ///
    /// Checked in this order:
    /// 1. `Contents/Resources/content.json` — the standard macOS app bundle
    ///    location, used by the built .app (see scripts/build-app.sh). Real
    ///    bundle layout, so codesign can seal it correctly.
    /// 2. `Bundle.module` — SPM's own resource bundle, used only under
    ///    `swift run`/`swift test` during development. Accessing it crashes
    ///    with fatalError if missing, so it's tried second, not first.
    static func load() throws -> Content {
        let url: URL
        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("content.json"),
           FileManager.default.fileExists(atPath: resourceURL.path) {
            url = resourceURL
        } else if let moduleURL = Bundle.module.url(forResource: "content", withExtension: "json") {
            url = moduleURL
        } else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Content.self, from: data)
    }
}
