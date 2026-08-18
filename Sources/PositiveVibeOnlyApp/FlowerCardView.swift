import SwiftUI
import PositiveVibeOnlyCore

/// The centre card: a disc — the flower's own centre — with two crisply
/// separated sections. The header band — tinted with the
/// day's flower colour — carries the caps greeting/date line, the flower
/// name (with its Vietnamese annotation), and the meaning. The cream body
/// below carries quote + author, the compliment, and a "TODAY" labelled
/// prompt. Text colour hue tracks the flower; only lightness changes
/// between light and dark mode.
struct CardContentView: View {
    let greeting: Greeting
    let name: String?
    let updateAvailable: Bool
    var onRefresh: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil
    var onTogglePin: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @State private var hoveringControls = false
    @State private var hoveredHint: String?
    // Shared with AppDelegate, which reads the same key to decide whether
    // clicks in other apps dismiss the card.
    @AppStorage("KeepCardOnScreen") private var isPinned = false

    private var colors: CardTextColors {
        BloomCatalog.textColors(for: greeting.flower?.name ?? "Daisy")
    }
    private var isDark: Bool { colorScheme == .dark }
    private var primary: Color { Color(hex: isDark ? colors.darkPrimary : colors.lightPrimary) }
    private var secondary: Color { Color(hex: isDark ? colors.darkSecondary : colors.lightSecondary) }
    private var muted: Color { Color(hex: isDark ? colors.darkMuted : colors.lightMuted) }
    private var cardFill: Color { Color(hex: isDark ? "#241A12" : "#FFFDFA") }
    // Strong enough to read as a solid pastel section against the cream
    // body, like the 6a mock — 0.15 washed out to near-invisible.
    private var headerTint: Color {
        let hex = BloomCatalog.spec(for: greeting.flower?.name ?? "Daisy").outerColorHex
        return Color(hex: hex).opacity(isDark ? 0.38 : 0.30)
    }
    private var bloomSpec: BloomSpec { BloomCatalog.spec(for: greeting.flower?.name ?? "Daisy") }
    /// Petal-coloured rim: a hairline gradient stroke plus a close-in glow,
    /// so the card meets the petals with light instead of a hard white cut.
    private var rimGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: bloomSpec.outerColorHex).opacity(0.55),
                                Color(hex: bloomSpec.innerColorHex).opacity(0.35)],
                       startPoint: .top, endPoint: .bottom)
    }
    private var glowColor: Color { Color(hex: bloomSpec.outerColorHex).opacity(isDark ? 0.5 : 0.38) }

    // The centre disc. Fixed, not content-driven: a flower's centre is a
    // constant part of the bloom, and a card that changed size with the
    // quote read as a balloon. 380 leaves ~110pt of every petal showing
    // past its edge (tips reach 300 from centre), so the bloom still reads
    // as a flower rather than a plate with petals behind it.
    private let diameter: CGFloat = 380

    // Per-block wrap widths, each a chord of the disc at that block's own
    // height: narrow at the top curve (header), widest across the middle
    // (quote), narrowing again toward the bottom (prompt). Kept ~20pt
    // inside the true chord so descenders never touch the rim.
    private let headerTextWidth: CGFloat = 208
    private let quoteTextWidth: CGFloat = 300
    private let complimentTextWidth: CGFloat = 276
    private let promptTextWidth: CGFloat = 244

    /// Small-caps section label, the mock's letterspaced style.
    private func capsText(_ s: String) -> Text {
        Text(s.uppercased())
            .font(.custom("Karla", size: 8.5))
            .fontWeight(.medium)
            .tracking(2)
    }

    private var headerDateLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        let date = formatter.string(from: Date())
        guard let name, !name.isEmpty else { return "Hello · \(date)" }
        return "Hi \(name) · \(date)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header band ──
            VStack(spacing: 5) {
                capsText(headerDateLine)
                    .foregroundColor(secondary)
                if let flower = greeting.flower {
                    // One concatenated Text so the Vietnamese annotation
                    // stays glued to the name; single line, scaling down
                    // rather than wrapping.
                    (Text(flower.name)
                        .font(.custom("Fraunces", size: 26))
                        .tracking(-0.5)
                        .foregroundColor(primary)
                     + Text(flower.nameVi.map { " (\($0))" } ?? "")
                        .font(.custom("Fraunces", size: 11.5))
                        .italic()
                        .foregroundColor(secondary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .allowsTightening(true)
                    Text(flower.meaning.noWidow(font: CardFont.fraunces(11.5), width: headerTextWidth))
                        .font(.custom("Fraunces", size: 11.5))
                        .italic()
                        .foregroundColor(secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2.5)
                }
            }
            .frame(width: headerTextWidth)
            .padding(.top, 34)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity)
            .background(headerTint)

            // ── Body ──
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("\u{201C}\(greeting.quote.text)\u{201D}".noWidow(font: CardFont.fraunces(16), width: quoteTextWidth))
                        .font(.custom("Fraunces", size: 16))
                        .italic()
                        .fontWeight(.semibold)
                        .foregroundColor(primary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3.5)
                    capsText(greeting.quote.author)
                        .foregroundColor(muted)
                }
                .frame(width: quoteTextWidth)

                Text(greeting.compliment.noWidow(font: CardFont.karla(12), width: complimentTextWidth))
                    .font(.custom("Karla", size: 12))
                    .tracking(0.2)
                    .foregroundColor(primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(width: complimentTextWidth)

                VStack(spacing: 4) {
                    capsText("Today")
                        .foregroundColor(secondary)
                    Text(greeting.prompt.title.noWidow(font: CardFont.karla(11), width: promptTextWidth))
                        .font(.custom("Karla", size: 11))
                        .foregroundColor(secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2.5)
                    Text(greeting.prompt.body.noWidow(font: CardFont.karla(10), width: promptTextWidth))
                        .font(.custom("Karla", size: 10))
                        .foregroundColor(muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                .frame(width: promptTextWidth)

                if updateAvailable {
                    Button {
                        openURL(UpdateChecker.releasesPageURL)
                    } label: {
                        Text("Update available →")
                            .font(.custom("Karla", size: 11.5))
                            .foregroundColor(muted)
                    }
                    .buttonStyle(.plain)
                }

                Text(versionLine)
                    .font(.custom("Karla", size: 8.5))
                    .tracking(0.4)
                    .foregroundColor(muted.opacity(0.4))
            }
            .padding(.top, 16)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity)
        }
        // Natural height regardless of the disc's proposal — without this
        // the square frame below squeezes the text into truncation.
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .background(
            Circle()
                .fill(cardFill)
                // Close-in tinted glow (no offset) melts the edge into the
                // petals; the wider offset shadow below keeps the depth.
                .shadow(color: glowColor, radius: 12, x: 0, y: 0)
                .shadow(color: shadowColor, radius: 20, x: 0, y: 6)
        )
        .overlay(
            Circle().stroke(rimGradient, lineWidth: 1.5)
                .allowsHitTesting(false)
        )
        // Two quiet controls in the dome, above the header text: refresh
        // (a fresh random draw) and close. Faint until hovered. The hint
        // line replaces `.help()` tooltips, which never appear on this
        // borderless non-activating panel — and instant beats a 1s delay.
        .overlay(alignment: .top) {
            VStack(spacing: 3) {
                HStack(spacing: 18) {
                    Button { onRefresh?() } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 18, height: 18)
                            .contentShape(Rectangle())
                    }
                    .onHover { hoveredHint = $0 ? "Another one" : nil }
                    Button {
                        isPinned.toggle()
                        onTogglePin?()
                    } label: {
                        Image(systemName: isPinned ? "pin.fill" : "pin")
                            .frame(width: 18, height: 18)
                            .contentShape(Rectangle())
                    }
                    .onHover { hoveredHint = $0 ? (isPinned ? "Let it close on its own" : "Keep on screen") : nil }
                    Button { onClose?() } label: {
                        Image(systemName: "xmark")
                            .frame(width: 18, height: 18)
                            .contentShape(Rectangle())
                    }
                    .onHover { hoveredHint = $0 ? "Close" : nil }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5, weight: .semibold))
                if let hoveredHint {
                    Text(hoveredHint)
                        .font(.custom("Karla", size: 9))
                        .tracking(0.4)
                        .transition(.opacity)
                }
            }
            .foregroundColor(secondary)
            .opacity(hoveringControls ? 1 : 0.8)
            .animation(.easeOut(duration: 0.15), value: hoveringControls)
            .animation(.easeOut(duration: 0.12), value: hoveredHint)
            .onHover { hoveringControls = $0 }
            .padding(.top, 14)
        }
    }

    /// "v1.1.0 · updated Aug 14, 2026". Version comes from the bundle the
    /// app is actually running from; the date is stamped into Info.plist by
    /// build-app.sh. Under `swift run` (no bundle plist) it shows "dev".
    private var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "dev"
        if let built = info?["PeonyBuildDate"] as? String {
            return "v\(version) · \(built)"
        }
        return "v\(version)"
    }

    private var shadowColor: Color {
        guard let flower = greeting.flower else { return .black.opacity(0.16) }
        return Color(hex: BloomCatalog.spec(for: flower.name).outerColorHex).opacity(isDark ? 0.35 : 0.16)
    }
}

/// Affectionate gift-note lines for the toast — one drawn at random per
/// show, so the hand-off never reads the same twice in a row.
enum GiftNotes {
    static func pick(name: String?, flower: String?) -> String {
        let flowerWord = flower?.lowercased() ?? "bloom"
        let dear = (name?.isEmpty == false ? name! : "beauty")
        return [
            "Hey beauty, these are for you 💐",
            // Singular/mass forms only: "+s" or "a \(flowerWord)" breaks on
            // names like Iris ("irises", "a iris"), so no line relies on either.
            "Psst, \(dear) — fresh \(flowerWord), just picked 🌷",
            "Someone thinks you're wonderful 🌸",
            "Special delivery for the loveliest \(dear)! 💐",
            "You looked like you needed flowers today 🌼",
            "Ta-da! This \(flowerWord) is for you ✨",
            "Hand-picked this morning, just for \(dear) 🌷",
            "A little \(flowerWord) to brighten your hour 🌸",
            "For you — no occasion needed 💮",
            "Surprise! Flowers for \(dear) 💐",
        ].randomElement()!
    }
}

/// A small gift-note toast: floats in above the bloom when the card
/// appears, lingers, then fades — the moment of being handed the flowers.
/// Not private: BreakCardView reuses this exact component for its own,
/// differently-worded toast pool.
struct GiftToast: View {
    let text: String
    let tint: Color
    @Environment(\.colorScheme) private var colorScheme
    @State private var visible = false

    var body: some View {
        Text(text)
            .font(.custom("Fraunces", size: 15))
            .italic()
            .foregroundColor(Color(hex: colorScheme == .dark ? "#F2E4D8" : "#6B4A3A"))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(hex: colorScheme == .dark ? "#241A12" : "#FFFDFA"))
                    .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 3)
            )
            .overlay(
                Capsule().strokeBorder(tint.opacity(0.55), lineWidth: 1)
            )
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.6)
            .offset(y: visible ? 0 : -14)
            .rotationEffect(.degrees(visible ? 0 : -3))
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.55)) {
                    visible = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                    withAnimation(.easeIn(duration: 0.5)) { visible = false }
                }
            }
    }
}

/// The full popover content: today's bloom behind, the centre disc
/// on top, authored in a 640x640 frame per the approved handoff spec and
/// scaled as a whole by `scaleState` (the Card Size menu).
struct FlowerCardView: View {
    let greeting: Greeting?
    let name: String?
    let toastText: String
    @ObservedObject var updateState: UpdateState
    @ObservedObject var scaleState: CardScaleState
    var onRefresh: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil
    var onTogglePin: (() -> Void)? = nil
    var onDragChanged: ((CGSize) -> Void)? = nil
    var onDragEnded: (() -> Void)? = nil


    // Same pattern as CardContentView.headerTint, minus the opacity — the
    // toast border draws its own translucency.
    private var toastTint: Color {
        let hex = BloomCatalog.spec(for: greeting?.flower?.name ?? "Daisy").outerColorHex
        return Color(hex: hex)
    }

    var body: some View {
        ZStack {
            if let flower = greeting?.flower {
                BloomView(spec: BloomCatalog.spec(for: flower.name))
            }
            if let greeting {
                CardContentView(greeting: greeting, name: name, updateAvailable: updateState.isAvailable,
                                onRefresh: onRefresh, onClose: onClose, onTogglePin: onTogglePin)
            } else {
                Text("Could not load today's content.")
                    .font(.custom("Karla", size: 13))
                    .foregroundColor(.secondary)
                    .padding(24)
                    .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .frame(width: CardScaleState.baseSize, height: CardScaleState.baseSize)
        .overlay(alignment: .top) {
            if greeting != nil {
                GiftToast(text: toastText, tint: toastTint)
                    .padding(.top, 56)
                    .allowsHitTesting(false)
                    // New identity per card so a refresh re-runs the toast —
                    // a fresh draw is a fresh gift.
                    .id(toastText + (greeting?.quote.text ?? ""))
            }
        }
        .cardScaled(scaleState.scale)
        // The drag sits outside .cardScaled deliberately: attached inside,
        // it would report translation in the card's own (scaled) coordinate
        // space, so a dragged card would lag or outrun the cursor at any
        // size but Medium.
        //
        // .simultaneousGesture (not .gesture) so this coexists with the
        // "Update available" button inside the card — a quick tap still
        // reaches the button; only an actual drag moves the window.
        .simultaneousGesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in onDragChanged?(value.translation) }
                .onEnded { _ in onDragEnded?() }
        )
    }
}
