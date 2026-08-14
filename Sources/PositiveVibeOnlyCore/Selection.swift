import Foundation

public struct Greeting {
    public let quote: Quote
    public let compliment: String
    public let prompt: PromptItem
    public let flower: Flower?
}

public enum Selection {
    /// Picks today's quote, compliment, prompt and flower from `content`.
    ///
    /// Deterministic in the date: everyone on the team sees the same
    /// greeting on the same day, no matter how many times they click the
    /// icon. Mon/Wed/Fri draw from prompt pool A, the rest of the week from
    /// pool B — pure function of `date` and `calendar`, no I/O.
    public static func greeting(for content: Content, date: Date = Date(), calendar: Calendar = .current) -> Greeting? {
        guard !content.quotes.isEmpty, !content.compliments.isEmpty else { return nil }

        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = calendar.component(.year, from: date)
        let dayIndex = year * 366 + dayOfYear
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday ... 7 = Saturday

        let wantsPoolA = [2, 4, 6].contains(weekday) // Mon, Wed, Fri
        let kind = wantsPoolA ? "A" : "B"
        let pool = content.prompts.filter { $0.kind == kind }
        let fallbackPool = pool.isEmpty ? content.prompts : pool
        guard !fallbackPool.isEmpty else { return nil }

        let quote = content.quotes[dayIndex % content.quotes.count]
        let compliment = content.compliments[dayIndex % content.compliments.count]
        let prompt = fallbackPool[dayIndex % fallbackPool.count]
        let flower = content.flowers.isEmpty ? nil : content.flowers[dayIndex % content.flowers.count]

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
