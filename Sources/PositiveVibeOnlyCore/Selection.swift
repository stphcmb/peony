import Foundation

public struct Greeting {
    public let quote: Quote
    public let compliment: String
    public let prompt: PromptItem
    public let flower: Flower?

    public init(quote: Quote, compliment: String, prompt: PromptItem, flower: Flower?) {
        self.quote = quote
        self.compliment = compliment
        self.prompt = prompt
        self.flower = flower
    }
}

public enum Selection {
    /// Picks this hour's quote, compliment and flower, plus today's prompt,
    /// from `content`.
    ///
    /// Deterministic in the date and hour: everyone on the team sees the
    /// same greeting in the same hour, no matter how many times they click
    /// the icon. The prompt alone stays fixed for the whole day — it's a
    /// day-scale invitation, not an hourly one — with Mon/Wed/Fri drawing
    /// from pool A and the rest of the week from pool B. Pure function of
    /// `date` and `calendar`, no I/O.
    public static func greeting(for content: Content, date: Date = Date(), calendar: Calendar = .current) -> Greeting? {
        guard !content.quotes.isEmpty, !content.compliments.isEmpty else { return nil }

        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = calendar.component(.year, from: date)
        let dayIndex = year * 366 + dayOfYear
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday ... 7 = Saturday
        let hour = calendar.component(.hour, from: date)

        // Indexing pools by the raw hour slot would walk each list in file
        // order, one entry per hour — a carousel, not a draw. Multiplying by
        // a large odd constant (Knuth's) before the modulo keeps the pick
        // deterministic but makes consecutive hours land somewhere fresh.
        let scrambled = (dayIndex * 24 + hour) &* 2654435761

        let wantsPoolA = [2, 4, 6].contains(weekday) // Mon, Wed, Fri
        let kind = wantsPoolA ? "A" : "B"
        let pool = content.prompts.filter { $0.kind == kind }
        let fallbackPool = pool.isEmpty ? content.prompts : pool
        guard !fallbackPool.isEmpty else { return nil }

        let quote = content.quotes[scrambled % content.quotes.count]
        let compliment = content.compliments[scrambled % content.compliments.count]
        let prompt = fallbackPool[dayIndex % fallbackPool.count]
        let flower = content.flowers.isEmpty ? nil : content.flowers[scrambled % content.flowers.count]

        return Greeting(quote: quote, compliment: compliment, prompt: prompt, flower: flower)
    }

    /// A one-off random greeting, for the "Surprise Me" menu action. Draws
    /// from every prompt pool (no weekday rule) and doesn't affect the
    /// deterministic daily pick above.
    public static func randomGreeting(for content: Content) -> Greeting? {
        guard let quote = content.quotes.randomElement(),
              let compliment = content.compliments.randomElement(),
              let prompt = content.prompts.randomElement() else { return nil }
        return Greeting(quote: quote, compliment: compliment, prompt: prompt, flower: content.flowers.randomElement())
    }
}
