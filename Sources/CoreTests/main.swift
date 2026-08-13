// Plain assertion-based test runner for PositiveVibeOnlyCore.
//
// No XCTest / swift-testing here on purpose: neither ships with the Command
// Line Tools alone (both need full Xcode), and pulling in Xcode just to run
// tests would defeat the "no Xcode needed" goal of this project. This runs
// the same logic checks would run under XCTest, just without the framework.
//
// Run with: swift run CoreTests

import Foundation
import PositiveVibeOnlyCore

var failures = 0

func check(_ name: String, _ condition: Bool) {
    if condition {
        print("ok   - \(name)")
    } else {
        print("FAIL - \(name)")
        failures += 1
    }
}

func utcCalendar() -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
}

func date(_ y: Int, _ m: Int, _ d: Int, _ calendar: Calendar) -> Date {
    DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: y, month: m, day: d).date!
}

func makeContent(prompts: [(String, String, String)], quotes: Int = 3, flowers: Int = 2) -> Content {
    Content(
        version: 1,
        quotes: (0..<quotes).map { Quote(text: "q\($0)", author: "a\($0)") },
        compliments: ["c0", "c1"],
        prompts: prompts.map { PromptItem(kind: $0.0, title: $0.1, body: $0.2) },
        flowers: (0..<flowers).map { Flower(name: "f\($0)", meaning: "m\($0)") }
    )
}

let calendar = utcCalendar()

// Monday 2026-08-10 should surface pool A.
do {
    let content = makeContent(prompts: [("A", "T", "tb"), ("B", "W", "wb")])
    let greeting = Selection.greeting(for: content, date: date(2026, 8, 10, calendar), calendar: calendar)
    check("Monday picks pool A", greeting?.prompt.kind == "A")
}

// Tuesday 2026-08-11 should surface pool B.
do {
    let content = makeContent(prompts: [("A", "T", "tb"), ("B", "W", "wb")])
    let greeting = Selection.greeting(for: content, date: date(2026, 8, 11, calendar), calendar: calendar)
    check("Tuesday picks pool B", greeting?.prompt.kind == "B")
}

// Same day, called twice, must return the same greeting.
do {
    let content = makeContent(prompts: [("A", "T", "tb"), ("B", "W", "wb")])
    let d = date(2026, 8, 12, calendar)
    let g1 = Selection.greeting(for: content, date: d, calendar: calendar)
    let g2 = Selection.greeting(for: content, date: d, calendar: calendar)
    check("same day is deterministic", g1?.quote.text == g2?.quote.text
        && g1?.compliment == g2?.compliment
        && g1?.prompt.title == g2?.prompt.title)
}

// Only pool B entries exist, but today wants pool A — must fall back, not return nil.
do {
    let content = makeContent(prompts: [("B", "W", "wb")])
    let greeting = Selection.greeting(for: content, date: date(2026, 8, 10, calendar), calendar: calendar)
    check("falls back to whole pool when kind missing", greeting?.prompt.title == "W")
}

// No quotes at all — must return nil, not crash.
do {
    let content = Content(version: 1, quotes: [], compliments: ["c0"], prompts: [PromptItem(kind: "A", title: "T", body: "b")], flowers: [])
    check("empty quotes returns nil", Selection.greeting(for: content, date: date(2026, 8, 10, calendar), calendar: calendar) == nil)
}

// No prompts at all — must return nil, not crash.
do {
    let content = makeContent(prompts: [])
    check("empty prompts returns nil", Selection.greeting(for: content, date: date(2026, 8, 10, calendar), calendar: calendar) == nil)
}

// Flowers rotate with the day, same as everything else.
do {
    let content = makeContent(prompts: [("A", "T", "tb")], flowers: 3)
    let greeting = Selection.greeting(for: content, date: date(2026, 8, 10, calendar), calendar: calendar)
    check("flower is picked when pool is non-empty", greeting?.flower != nil)
}

// No flowers in the pool — must degrade to nil, not crash the whole greeting.
do {
    let content = makeContent(prompts: [("A", "T", "tb")], flowers: 0)
    let greeting = Selection.greeting(for: content, date: date(2026, 8, 10, calendar), calendar: calendar)
    check("missing flower pool degrades to nil, not a crash", greeting != nil && greeting?.flower == nil)
}

// BloomCatalog covers every flower name that actually ships in content.json —
// a name typo here would silently fall back to Daisy's shape at runtime.
do {
    let shippedNames = [
        "Sunflower", "Cherry Blossom", "Lotus", "Lavender", "Peony", "Daisy", "Orchid", "Tulip",
        "Iris", "Chrysanthemum", "Marigold", "Poppy", "Camellia", "Jasmine", "Hydrangea", "Wisteria",
        "Magnolia", "Freesia", "Anemone", "Ranunculus", "Gerbera", "Snapdragon", "Zinnia", "Carnation",
        "Bluebell", "Hibiscus", "Forget-Me-Not", "Amaryllis", "Dahlia", "Protea"
    ]
    var allCovered = true
    for name in shippedNames {
        let spec = BloomCatalog.spec(for: name)
        // A real catalog entry for "Daisy" itself is indistinguishable from a
        // fallback-to-Daisy, so that one name is exempted from this check.
        if name != "Daisy" && spec.outerColorHex == BloomCatalog.spec(for: "Daisy").outerColorHex
            && spec.outer.count == BloomCatalog.spec(for: "Daisy").outer.count {
            allCovered = false
        }
    }
    check("every shipped flower name has its own bloom spec", allCovered)
}

if failures > 0 {
    print("\n\(failures) failure(s)")
    exit(1)
} else {
    print("\nall checks passed")
}
