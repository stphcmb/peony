import Foundation

public struct Quote: Decodable {
    public let text: String
    public let author: String

    public init(text: String, author: String) {
        self.text = text
        self.author = author
    }
}

/// The card's fourth block: not a fact to learn, but an invitation — a
/// question worth sitting with, a specific act of kindness, or a nudge
/// toward rest. `kind` is an internal pool tag ("A"/"B"), not shown in the
/// UI — it only drives which weekday sees which pool, the same mechanism
/// the old tech/world split used.
public struct PromptItem: Decodable {
    public let kind: String
    public let title: String
    public let body: String

    public init(kind: String, title: String, body: String) {
        self.kind = kind
        self.title = title
        self.body = body
    }
}

public struct Flower: Decodable {
    public let name: String
    public let meaning: String
    /// Vietnamese name, shown as a small annotation next to `name`.
    /// Optional so content.json entries without one keep decoding.
    public let nameVi: String?

    public init(name: String, meaning: String, nameVi: String? = nil) {
        self.name = name
        self.meaning = meaning
        self.nameVi = nameVi
    }
}

public struct Content: Decodable {
    public let version: Int
    public let quotes: [Quote]
    public let compliments: [String]
    public let prompts: [PromptItem]
    public let flowers: [Flower]

    public init(version: Int, quotes: [Quote], compliments: [String], prompts: [PromptItem], flowers: [Flower]) {
        self.version = version
        self.quotes = quotes
        self.compliments = compliments
        self.prompts = prompts
        self.flowers = flowers
    }
}
