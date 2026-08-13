import Foundation

/// How a petal's inner edge (the end nearest the bloom's centre) is drawn.
/// The outer tip is always fully round. `.squared` gives the base a flatter,
/// less pointed meeting with the centre — matches how ray-petalled flowers
/// (cosmos, daisies) look next to cupped ones (peony, rose).
public enum PetalTip: Equatable, Sendable {
    case round
    case squared(baseRadius: Double)
}

/// One ring of petals: count, size, how far its centre sits from the
/// bloom's centre, the angle of the first petal, and its tip style.
public struct PetalRing: Equatable, Sendable {
    public let count: Int
    public let width: Double
    public let length: Double
    public let offset: Double
    public let startAngle: Double
    public let tip: PetalTip

    public init(count: Int, width: Double, length: Double, offset: Double, startAngle: Double = 0, tip: PetalTip = .round) {
        self.count = count
        self.width = width
        self.length = length
        self.offset = offset
        self.startAngle = startAngle
        self.tip = tip
    }

    /// The rim pass: a slightly larger, further-out copy of this ring in the
    /// die-cut off-white, same rotations. This is what makes the whole
    /// silhouette read as a trimmed sticker rather than flat petals.
    public var rim: PetalRing {
        PetalRing(count: count, width: width + 12, length: length + 12, offset: offset + 6, startAngle: startAngle, tip: tip)
    }
}

/// Everything needed to draw one flower's bloom: two petal rings and the
/// two colours that fill them. The rim colour is fixed (see BloomView) —
/// it never changes with the flower or with light/dark mode.
public struct BloomSpec: Equatable, Sendable {
    public let outer: PetalRing
    public let inner: PetalRing
    public let outerColorHex: String
    public let innerColorHex: String

    public init(outer: PetalRing, inner: PetalRing, outerColorHex: String, innerColorHex: String) {
        self.outer = outer
        self.inner = inner
        self.outerColorHex = outerColorHex
        self.innerColorHex = innerColorHex
    }
}

/// Text colours for the centre card. Hue tracks the flower; lightness
/// pattern is fixed, matching the two documented examples (peony pink,
/// cosmos purple) so every flower reads as "the same card, different tint"
/// rather than thirty unrelated palettes.
public struct CardTextColors: Equatable, Sendable {
    public let lightPrimary: String
    public let lightSecondary: String
    public let lightMuted: String
    public let lightDash: String
    public let darkPrimary: String
    public let darkSecondary: String
    public let darkMuted: String
    public let darkDash: String

    public init(lightPrimary: String, lightSecondary: String, lightMuted: String, lightDash: String,
                darkPrimary: String, darkSecondary: String, darkMuted: String, darkDash: String) {
        self.lightPrimary = lightPrimary
        self.lightSecondary = lightSecondary
        self.lightMuted = lightMuted
        self.lightDash = lightDash
        self.darkPrimary = darkPrimary
        self.darkSecondary = darkSecondary
        self.darkMuted = darkMuted
        self.darkDash = darkDash
    }
}

public enum BloomCatalog {
    /// Off-white used for the rim (die-cut edge) pass. Constant across every
    /// flower and across light/dark mode — only the centre card changes with
    /// appearance, never the bloom itself.
    public static let rimColorHex = "#FFFDFA"

    public static func spec(for flowerName: String) -> BloomSpec {
        blooms[flowerName] ?? blooms["Daisy"]!
    }

    public static func textColors(for flowerName: String) -> CardTextColors {
        colors[flowerName] ?? colors["Daisy"]!
    }

    // MARK: - Geometry

    // Peony and Marigold are the exact numbers from the approved handoff
    // spec. Every other row follows the same rule (rim = outer +12/+12
    // size, +6 offset, same rotations) with counts/sizes/colours chosen to
    // suit each flower's real silhouette.
    private static let blooms: [String: BloomSpec] = [
        "Peony": BloomSpec(
            outer: PetalRing(count: 8, width: 156, length: 280, offset: 142, tip: .round),
            inner: PetalRing(count: 5, width: 120, length: 208, offset: 104, startAngle: 22, tip: .round),
            outerColorHex: "#F4A8BC", innerColorHex: "#EE8AA4"
        ),
        "Marigold": BloomSpec(
            outer: PetalRing(count: 12, width: 96, length: 300, offset: 150, tip: .round),
            inner: PetalRing(count: 6, width: 108, length: 210, offset: 104, startAngle: 15, tip: .round),
            outerColorHex: "#E2903A", innerColorHex: "#C97620"
        ),
        "Iris": BloomSpec(
            outer: PetalRing(count: 5, width: 188, length: 288, offset: 146, tip: .squared(baseRadius: 40)),
            inner: PetalRing(count: 5, width: 150, length: 210, offset: 106, startAngle: 36, tip: .round),
            outerColorHex: "#C9A6EE", innerColorHex: "#B189E4"
        ),
        "Sunflower": BloomSpec(
            outer: PetalRing(count: 13, width: 104, length: 310, offset: 152, tip: .squared(baseRadius: 26)),
            inner: PetalRing(count: 7, width: 96, length: 170, offset: 90, startAngle: 12, tip: .round),
            outerColorHex: "#F6C94A", innerColorHex: "#C97B2E"
        ),
        "Cherry Blossom": BloomSpec(
            outer: PetalRing(count: 5, width: 176, length: 250, offset: 128, tip: .squared(baseRadius: 60)),
            inner: PetalRing(count: 5, width: 96, length: 150, offset: 82, startAngle: 36, tip: .round),
            outerColorHex: "#FBD3DE", innerColorHex: "#F4A9BE"
        ),
        "Lotus": BloomSpec(
            outer: PetalRing(count: 10, width: 130, length: 296, offset: 148, tip: .round),
            inner: PetalRing(count: 6, width: 112, length: 196, offset: 98, startAngle: 18, tip: .round),
            outerColorHex: "#FBDCE6", innerColorHex: "#F2A9C2"
        ),
        "Lavender": BloomSpec(
            outer: PetalRing(count: 9, width: 92, length: 268, offset: 138, tip: .round),
            inner: PetalRing(count: 5, width: 84, length: 176, offset: 92, startAngle: 20, tip: .round),
            outerColorHex: "#C6B6EE", innerColorHex: "#9F86D6"
        ),
        "Daisy": BloomSpec(
            outer: PetalRing(count: 14, width: 78, length: 300, offset: 150, tip: .squared(baseRadius: 20)),
            inner: PetalRing(count: 5, width: 74, length: 150, offset: 82, startAngle: 18, tip: .round),
            outerColorHex: "#FFFBF0", innerColorHex: "#F6C94A"
        ),
        "Tulip": BloomSpec(
            outer: PetalRing(count: 6, width: 190, length: 270, offset: 132, tip: .squared(baseRadius: 46)),
            inner: PetalRing(count: 3, width: 118, length: 170, offset: 84, startAngle: 30, tip: .round),
            outerColorHex: "#F4879C", innerColorHex: "#E0546F"
        ),
        "Chrysanthemum": BloomSpec(
            outer: PetalRing(count: 16, width: 66, length: 300, offset: 150, tip: .round),
            inner: PetalRing(count: 8, width: 60, length: 200, offset: 94, startAngle: 10, tip: .round),
            outerColorHex: "#FBEADB", innerColorHex: "#EAB868"
        ),
        "Camellia": BloomSpec(
            outer: PetalRing(count: 7, width: 150, length: 264, offset: 134, tip: .round),
            inner: PetalRing(count: 5, width: 108, length: 176, offset: 88, startAngle: 24, tip: .round),
            outerColorHex: "#F3A6A0", innerColorHex: "#DE6E68"
        ),
        "Jasmine": BloomSpec(
            outer: PetalRing(count: 5, width: 118, length: 250, offset: 128, tip: .round),
            inner: PetalRing(count: 5, width: 60, length: 130, offset: 70, startAngle: 36, tip: .round),
            outerColorHex: "#FFFDF6", innerColorHex: "#F6DFA0"
        ),
        "Hydrangea": BloomSpec(
            outer: PetalRing(count: 10, width: 108, length: 258, offset: 132, tip: .squared(baseRadius: 34)),
            inner: PetalRing(count: 6, width: 96, length: 170, offset: 88, startAngle: 14, tip: .round),
            outerColorHex: "#AFC9EE", innerColorHex: "#7FA3DE"
        ),
        "Wisteria": BloomSpec(
            outer: PetalRing(count: 6, width: 128, length: 272, offset: 136, tip: .round),
            inner: PetalRing(count: 4, width: 90, length: 168, offset: 86, startAngle: 28, tip: .round),
            outerColorHex: "#CBB6EA", innerColorHex: "#9C7ACB"
        ),
        "Magnolia": BloomSpec(
            outer: PetalRing(count: 6, width: 176, length: 282, offset: 140, tip: .squared(baseRadius: 52)),
            inner: PetalRing(count: 3, width: 108, length: 168, offset: 82, startAngle: 34, tip: .round),
            outerColorHex: "#FBF1E6", innerColorHex: "#EBC9A6"
        ),
        "Freesia": BloomSpec(
            outer: PetalRing(count: 6, width: 100, length: 240, offset: 122, tip: .round),
            inner: PetalRing(count: 4, width: 70, length: 138, offset: 74, startAngle: 32, tip: .round),
            outerColorHex: "#FBEFC2", innerColorHex: "#EFCE6A"
        ),
        "Anemone": BloomSpec(
            outer: PetalRing(count: 7, width: 138, length: 260, offset: 132, tip: .round),
            inner: PetalRing(count: 6, width: 70, length: 132, offset: 66, startAngle: 16, tip: .round),
            outerColorHex: "#FFFFFF", innerColorHex: "#2C2430"
        ),
        "Ranunculus": BloomSpec(
            outer: PetalRing(count: 11, width: 108, length: 274, offset: 140, tip: .round),
            inner: PetalRing(count: 7, width: 92, length: 186, offset: 92, startAngle: 12, tip: .round),
            outerColorHex: "#F7C9AE", innerColorHex: "#EC9A6E"
        ),
        "Gerbera": BloomSpec(
            outer: PetalRing(count: 13, width: 84, length: 302, offset: 152, tip: .squared(baseRadius: 22)),
            inner: PetalRing(count: 5, width: 78, length: 158, offset: 84, startAngle: 16, tip: .round),
            outerColorHex: "#F4784E", innerColorHex: "#D9522C"
        ),
        "Snapdragon": BloomSpec(
            outer: PetalRing(count: 4, width: 150, length: 236, offset: 118, tip: .squared(baseRadius: 58)),
            inner: PetalRing(count: 4, width: 84, length: 138, offset: 70, startAngle: 45, tip: .round),
            outerColorHex: "#F5AECF", innerColorHex: "#E27FAE"
        ),
        "Zinnia": BloomSpec(
            outer: PetalRing(count: 10, width: 118, length: 288, offset: 146, tip: .squared(baseRadius: 28)),
            inner: PetalRing(count: 6, width: 96, length: 182, offset: 92, startAngle: 18, tip: .round),
            outerColorHex: "#F4635B", innerColorHex: "#D93A3A"
        ),
        "Carnation": BloomSpec(
            outer: PetalRing(count: 15, width: 76, length: 296, offset: 148, tip: .squared(baseRadius: 16)),
            inner: PetalRing(count: 9, width: 68, length: 190, offset: 92, startAngle: 8, tip: .squared(baseRadius: 14)),
            outerColorHex: "#F6B7C4", innerColorHex: "#E787A0"
        ),
        "Bluebell": BloomSpec(
            outer: PetalRing(count: 6, width: 86, length: 230, offset: 116, tip: .squared(baseRadius: 40)),
            inner: PetalRing(count: 3, width: 56, length: 116, offset: 60, startAngle: 40, tip: .round),
            outerColorHex: "#A9B8EA", innerColorHex: "#6E82D2"
        ),
        "Hibiscus": BloomSpec(
            outer: PetalRing(count: 5, width: 182, length: 280, offset: 140, tip: .round),
            inner: PetalRing(count: 3, width: 60, length: 130, offset: 62, startAngle: 30, tip: .round),
            outerColorHex: "#F4536B", innerColorHex: "#C81C3E"
        ),
        "Forget-Me-Not": BloomSpec(
            outer: PetalRing(count: 5, width: 96, length: 214, offset: 108, tip: .squared(baseRadius: 42)),
            inner: PetalRing(count: 5, width: 52, length: 92, offset: 48, startAngle: 36, tip: .round),
            outerColorHex: "#AECFEF", innerColorHex: "#F6DE7A"
        ),
        "Amaryllis": BloomSpec(
            outer: PetalRing(count: 6, width: 172, length: 290, offset: 146, tip: .round),
            inner: PetalRing(count: 3, width: 94, length: 162, offset: 82, startAngle: 32, tip: .round),
            outerColorHex: "#EE5C6C", innerColorHex: "#C82E42"
        ),
        "Dahlia": BloomSpec(
            outer: PetalRing(count: 16, width: 92, length: 296, offset: 150, tip: .squared(baseRadius: 30)),
            inner: PetalRing(count: 9, width: 78, length: 192, offset: 92, startAngle: 9, tip: .squared(baseRadius: 24)),
            outerColorHex: "#F0836A", innerColorHex: "#D8523A"
        ),
        "Protea": BloomSpec(
            outer: PetalRing(count: 12, width: 96, length: 306, offset: 154, tip: .squared(baseRadius: 24)),
            inner: PetalRing(count: 7, width: 84, length: 188, offset: 92, startAngle: 11, tip: .round),
            outerColorHex: "#EBB2A6", innerColorHex: "#C86A5C"
        ),
        "Poppy": BloomSpec(
            outer: PetalRing(count: 4, width: 200, length: 264, offset: 130, tip: .squared(baseRadius: 64)),
            inner: PetalRing(count: 3, width: 60, length: 110, offset: 54, startAngle: 45, tip: .round),
            outerColorHex: "#F0523E", innerColorHex: "#241C1E"
        ),
        "Orchid": BloomSpec(
            outer: PetalRing(count: 5, width: 168, length: 258, offset: 130, tip: .squared(baseRadius: 50)),
            inner: PetalRing(count: 3, width: 78, length: 138, offset: 66, startAngle: 60, tip: .round),
            outerColorHex: "#E3A6E4", innerColorHex: "#B85CC0"
        ),
    ]

    // MARK: - Text colours

    private static let colors: [String: CardTextColors] = [
        "Peony": CardTextColors(lightPrimary: "#40222C", lightSecondary: "#7A5A64", lightMuted: "#A5808F", lightDash: "#F0C3CF",
                                 darkPrimary: "#FBF3E8", darkSecondary: "#C4AE95", darkMuted: "#A08C73", darkDash: "#4A3722"),
        "Marigold": CardTextColors(lightPrimary: "#3D2A12", lightSecondary: "#7A5A34", lightMuted: "#A5824F", lightDash: "#F0D9B0",
                                    darkPrimary: "#FBF3E8", darkSecondary: "#C4AE95", darkMuted: "#A08C73", darkDash: "#4A3722"),
        "Iris": CardTextColors(lightPrimary: "#2E2440", lightSecondary: "#5F5476", lightMuted: "#8B7DA8", lightDash: "#DCC8F2",
                                darkPrimary: "#EDE6F9", darkSecondary: "#B8A8D9", darkMuted: "#8F7DB0", darkDash: "#382C52"),
        "Sunflower": CardTextColors(lightPrimary: "#3D3110", lightSecondary: "#7A6530", lightMuted: "#A5904F", lightDash: "#F2E1A0",
                                     darkPrimary: "#FBF3E0", darkSecondary: "#C9B57F", darkMuted: "#A0925F", darkDash: "#4A3E1A"),
        "Cherry Blossom": CardTextColors(lightPrimary: "#4A222E", lightSecondary: "#835A67", lightMuted: "#B08693", lightDash: "#F6D6E1",
                                          darkPrimary: "#FBF0F3", darkSecondary: "#D3AEBB", darkMuted: "#A88C97", darkDash: "#4A2E38"),
        "Lotus": CardTextColors(lightPrimary: "#442230", lightSecondary: "#7C5866", lightMuted: "#A9808F", lightDash: "#F6D2E2",
                                 darkPrimary: "#FBF0F5", darkSecondary: "#CFA9BB", darkMuted: "#A5879A", darkDash: "#43283A"),
        "Lavender": CardTextColors(lightPrimary: "#31264A", lightSecondary: "#635882", lightMuted: "#9084AC", lightDash: "#DED0F4",
                                    darkPrimary: "#F2EEFB", darkSecondary: "#BFB2D9", darkMuted: "#9284AF", darkDash: "#332B4A"),
        "Daisy": CardTextColors(lightPrimary: "#3A2E10", lightSecondary: "#736230", lightMuted: "#A0904F", lightDash: "#F4E9B8",
                                 darkPrimary: "#FBF7E8", darkSecondary: "#CEC090", darkMuted: "#A69A6F", darkDash: "#403A1E"),
        "Tulip": CardTextColors(lightPrimary: "#450F1E", lightSecondary: "#833048", lightMuted: "#B06A80", lightDash: "#F6C3D1",
                                 darkPrimary: "#FBE9EE", darkSecondary: "#D99CAC", darkMuted: "#A9808E", darkDash: "#4A1E2C"),
        "Chrysanthemum": CardTextColors(lightPrimary: "#3D3018", lightSecondary: "#7A6538", lightMuted: "#A59460", lightDash: "#EFDCB0",
                                         darkPrimary: "#FBF3E0", darkSecondary: "#C9B57F", darkMuted: "#A0925F", darkDash: "#4A3E1A"),
        "Camellia": CardTextColors(lightPrimary: "#421C1A", lightSecondary: "#7C4C48", lightMuted: "#A87d78", lightDash: "#F2C7C2",
                                    darkPrimary: "#FBEBE9", darkSecondary: "#D3A9A4", darkMuted: "#A88784", darkDash: "#442420"),
        "Jasmine": CardTextColors(lightPrimary: "#403420", lightSecondary: "#7A6a4c", lightMuted: "#a5977c", lightDash: "#F2E4C0",
                                   darkPrimary: "#FBF6E8", darkSecondary: "#D0C09A", darkMuted: "#a89a7c", darkDash: "#463c24"),
        "Hydrangea": CardTextColors(lightPrimary: "#1E2C42", lightSecondary: "#4F6078", lightMuted: "#7E93A8", lightDash: "#C7D8F0",
                                     darkPrimary: "#E8EFFB", darkSecondary: "#A9BEDA", darkMuted: "#8098B8", darkDash: "#26344A"),
        "Wisteria": CardTextColors(lightPrimary: "#2E2044", lightSecondary: "#5f5078", lightMuted: "#8c7ea6", lightDash: "#DCCBF2",
                                    darkPrimary: "#F2EDFB", darkSecondary: "#BEB0D9", darkMuted: "#9184af", darkDash: "#33294a"),
        "Magnolia": CardTextColors(lightPrimary: "#3A2A18", lightSecondary: "#725c40", lightMuted: "#a08c6c", lightDash: "#EBDBC2",
                                    darkPrimary: "#FBF4E8", darkSecondary: "#CBB899", darkMuted: "#a4926f", darkDash: "#3e321e"),
        "Freesia": CardTextColors(lightPrimary: "#3D3210", lightSecondary: "#79682e", lightMuted: "#a5944e", lightDash: "#F2E6A6",
                                   darkPrimary: "#FBF6E2", darkSecondary: "#CDBD82", darkMuted: "#a89860", darkDash: "#463c18"),
        "Anemone": CardTextColors(lightPrimary: "#241F26", lightSecondary: "#564e5a", lightMuted: "#847a8a", lightDash: "#DCD4E2",
                                   darkPrimary: "#F2EEF4", darkSecondary: "#BAB0C2", darkMuted: "#8f8496", darkDash: "#2c2730"),
        "Ranunculus": CardTextColors(lightPrimary: "#442414", lightSecondary: "#7c5638", lightMuted: "#a9805e", lightDash: "#F2D8BE",
                                      darkPrimary: "#FBEEE2", darkSecondary: "#D2B090", darkMuted: "#a88e6f", darkDash: "#442e1c"),
        "Gerbera": CardTextColors(lightPrimary: "#421C10", lightSecondary: "#7c422c", lightMuted: "#a8735a", lightDash: "#F2C4AE",
                                   darkPrimary: "#FBE7DE", darkSecondary: "#D3a289", darkMuted: "#a8836f", darkDash: "#442418"),
        "Snapdragon": CardTextColors(lightPrimary: "#421530", lightSecondary: "#7c3d5e", lightMuted: "#a86e91", lightDash: "#F4CBDF",
                                      darkPrimary: "#FBE9F1", darkSecondary: "#D3a3bd", darkMuted: "#a8839a", darkDash: "#441c34"),
        "Zinnia": CardTextColors(lightPrimary: "#3D1210", lightSecondary: "#7a3230", lightMuted: "#a56260", lightDash: "#F2BFBB",
                                  darkPrimary: "#FBE4E2", darkSecondary: "#D39794", darkMuted: "#a87c7a", darkDash: "#43201e"),
        "Carnation": CardTextColors(lightPrimary: "#421A26", lightSecondary: "#7c4456", lightMuted: "#a87c8c", lightDash: "#F4CFDA",
                                     darkPrimary: "#FBECF1", darkSecondary: "#D3AABB", darkMuted: "#a8899a", darkDash: "#442032"),
        "Bluebell": CardTextColors(lightPrimary: "#1E2244", lightSecondary: "#4e5478", lightMuted: "#7e84a8", lightDash: "#C7CDF2",
                                    darkPrimary: "#E8EBFB", darkSecondary: "#A9AFD9", darkMuted: "#8086b8", darkDash: "#262c4a"),
        "Hibiscus": CardTextColors(lightPrimary: "#420B14", lightSecondary: "#7c2d3a", lightMuted: "#a85e6a", lightDash: "#F2B8C3",
                                    darkPrimary: "#FBE1E6", darkSecondary: "#D38f9a", darkMuted: "#a87681", darkDash: "#44161e"),
        "Forget-Me-Not": CardTextColors(lightPrimary: "#1C2640", lightSecondary: "#4c5c78", lightMuted: "#7c90a8", lightDash: "#C7D6F0",
                                         darkPrimary: "#E8EEFB", darkSecondary: "#A6BADA", darkMuted: "#7e94b8", darkDash: "#243048"),
        "Amaryllis": CardTextColors(lightPrimary: "#420E14", lightSecondary: "#7c303a", lightMuted: "#a8626a", lightDash: "#F2BAC1",
                                     darkPrimary: "#FBE2E4", darkSecondary: "#D39298", darkMuted: "#a87880", darkDash: "#44181e"),
        "Dahlia": CardTextColors(lightPrimary: "#3D1810", lightSecondary: "#7a3e2e", lightMuted: "#a5715f", lightDash: "#F2CABB",
                                  darkPrimary: "#FBE9E2", darkSecondary: "#D3A794", darkMuted: "#a88b7a", darkDash: "#432418"),
        "Protea": CardTextColors(lightPrimary: "#3A211A", lightSecondary: "#725046", lightMuted: "#a08476", lightDash: "#EFD4C7",
                                  darkPrimary: "#FBEEE8", darkSecondary: "#CBB0a4", darkMuted: "#a4897c", darkDash: "#3e2a22"),
        "Poppy": CardTextColors(lightPrimary: "#3D1210", lightSecondary: "#7a322e", lightMuted: "#a5625e", lightDash: "#F2C0BA",
                                 darkPrimary: "#FBE5E2", darkSecondary: "#D39a94", darkMuted: "#a8807a", darkDash: "#43201d"),
        "Orchid": CardTextColors(lightPrimary: "#3A1440", lightSecondary: "#723c78", lightMuted: "#a06ea8", lightDash: "#EFC6f0",
                                  darkPrimary: "#F8E8FB", darkSecondary: "#CBA0d3", darkMuted: "#a47ca8", darkDash: "#3e1c46"),
    ]
}
