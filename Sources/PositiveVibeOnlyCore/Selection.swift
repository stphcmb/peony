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

        let slot = dayIndex * 24 + hour

        let wantsPoolA = [2, 4, 6].contains(weekday) // Mon, Wed, Fri
        let kind = wantsPoolA ? "A" : "B"
        let pool = content.prompts.filter { $0.kind == kind }
        let fallbackPool = pool.isEmpty ? content.prompts : pool
        guard !fallbackPool.isEmpty else { return nil }

        let quote = content.quotes[pick(slot: slot, salt: 1, count: content.quotes.count)]
        let compliment = content.compliments[pick(slot: slot, salt: 2, count: content.compliments.count)]
        let prompt = fallbackPool[dayIndex % fallbackPool.count]
        let flower = content.flowers.isEmpty ? nil
            : content.flowers[pick(slot: slot, salt: 3, count: content.flowers.count)]

        return Greeting(quote: quote, compliment: compliment, prompt: prompt, flower: flower)
    }

    /// Deterministic draw for one component of the hour's greeting. The
    /// splitmix64 finalizer (nonlinear, unlike a shared multiply-then-modulo)
    /// plus a per-component salt keeps quote, compliment and flower
    /// independent of each other: with one shared linear index, equal-size
    /// pools lock into fixed pairings forever — flower i always bringing
    /// compliment i — and only lcm(sizes) of the possible combinations ever
    /// appear. Still a pure function of the hour slot, so the whole team
    /// sees the same card in the same hour.
    private static func pick(slot: Int, salt: UInt64, count: Int) -> Int {
        var z = UInt64(bitPattern: Int64(slot)) &+ (salt &* 0x9E3779B97F4A7C15)
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return Int(z % UInt64(count))
    }

    /// A one-off random greeting, for the "Surprise Me" menu action. Draws
    /// from every prompt pool (no weekday rule) and doesn't affect the
    /// deterministic daily pick above. Each component avoids repeating
    /// what's currently on screen (`avoiding`) — an honest die repeats
    /// back-to-back 1-in-pool-size clicks, and a "randomize" that shows the
    /// same TODAY twice in a row reads as broken even when it isn't.
    public static func randomGreeting(for content: Content, avoiding current: Greeting? = nil) -> Greeting? {
        guard let quote = draw(content.quotes, avoiding: { $0.text == current?.quote.text }),
              let compliment = draw(content.compliments, avoiding: { $0 == current?.compliment }),
              let prompt = draw(content.prompts, avoiding: { $0.title == current?.prompt.title }) else { return nil }
        let flower = draw(content.flowers, avoiding: { $0.name == current?.flower?.name })
        return Greeting(quote: quote, compliment: compliment, prompt: prompt, flower: flower)
    }

    /// Random element, excluding the current one when the pool is big
    /// enough to offer an alternative (a 1-item pool keeps repeating —
    /// the only honest option).
    private static func draw<T>(_ pool: [T], avoiding isCurrent: (T) -> Bool) -> T? {
        let fresh = pool.filter { !isCurrent($0) }
        return (fresh.isEmpty ? pool : fresh).randomElement()
    }
}
