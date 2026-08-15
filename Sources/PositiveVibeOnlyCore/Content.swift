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

/// A break-reminder nudge: what to do and why, in one short imperative
/// line plus a specific detail. `kind` tags what the nudge is about (water,
/// eyes, stretch, ...) — not shown in the UI, just there for future pool
/// curation.
public struct CareNudge: Decodable {
    public let kind: String
    public let title: String
    public let body: String

    public init(kind: String, title: String, body: String) {
        self.kind = kind
        self.title = title
        self.body = body
    }
}

public struct Content: Decodable {
    public let version: Int
    public let quotes: [Quote]
    public let compliments: [String]
    public let prompts: [PromptItem]
    public let flowers: [Flower]
    /// Absent from content.json files that predate the break-reminders
    /// feature — decodes to `[]` rather than failing the whole load.
    public let careNudges: [CareNudge]

    public init(version: Int, quotes: [Quote], compliments: [String], prompts: [PromptItem], flowers: [Flower],
                careNudges: [CareNudge] = []) {
        self.version = version
        self.quotes = quotes
        self.compliments = compliments
        self.prompts = prompts
        self.flowers = flowers
        self.careNudges = careNudges
    }

    private enum CodingKeys: String, CodingKey {
        case version, quotes, compliments, prompts, flowers, careNudges
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        quotes = try container.decode([Quote].self, forKey: .quotes)
        compliments = try container.decode([String].self, forKey: .compliments)
        prompts = try container.decode([PromptItem].self, forKey: .prompts)
        flowers = try container.decode([Flower].self, forKey: .flowers)
        careNudges = try container.decodeIfPresent([CareNudge].self, forKey: .careNudges) ?? []
    }
}
