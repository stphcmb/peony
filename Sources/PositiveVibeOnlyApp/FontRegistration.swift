import CoreText
import Foundation

enum FontRegistration {
    /// Registers the bundled Fraunces and Karla variable fonts so SwiftUI's
    /// `.custom("Fraunces", ...)` / `.custom("Karla", ...)` can find them.
    /// Must run before any view renders. Missing or unregisterable fonts are
    /// not fatal — SwiftUI silently falls back to the system font, so a
    /// broken bundle degrades the look rather than crashing the app.
    static func registerBundledFonts() {
        for name in ["Fraunces", "Karla"] {
            guard let url = fontURL(named: name) else { continue }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            // CTFontManagerRegisterFontsForURL fails harmlessly if a previous
            // launch already registered the same font in this process — not
            // worth surfacing.
        }
    }

    private static func fontURL(named name: String) -> URL? {
        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("\(name).ttf"),
           FileManager.default.fileExists(atPath: resourceURL.path) {
            return resourceURL
        }
        return Bundle.module.url(forResource: name, withExtension: "ttf")
    }
}
