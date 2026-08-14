import Foundation
import PositiveVibeOnlyCore

struct SavedQuote: Codable, Equatable {
    let text: String
    let author: String
    let savedAt: Date
}

/// Hearted quotes, kept in UserDefaults — local only, in keeping with the
/// app's "nothing leaves this Mac" stance. Newest first.
enum SavedQuotesStore {
    private static let key = "SavedQuotes.v1"

    static func all() -> [SavedQuote] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([SavedQuote].self, from: data) else { return [] }
        return saved
    }

    static func isSaved(text: String) -> Bool {
        all().contains { $0.text == text }
    }

    /// Toggles the quote in/out of the saved list. Returns whether it is
    /// saved after the toggle.
    @discardableResult
    static func toggle(_ quote: Quote) -> Bool {
        var saved = all()
        if let index = saved.firstIndex(where: { $0.text == quote.text }) {
            saved.remove(at: index)
        } else {
            saved.insert(SavedQuote(text: quote.text, author: quote.author, savedAt: Date()), at: 0)
        }
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: key)
        }
        return saved.contains { $0.text == quote.text }
    }
}
