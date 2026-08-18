import SwiftUI
import PositiveVibeOnlyCore

/// Break-flavored gift-note lines — same "one drawn at random per show"
/// pool as GiftNotes, worded for "step away" instead of "here's your bloom."
enum BreakToasts {
    static func pick() -> String {
        [
            "Hey beauty, the work will wait 🌸",
            "Bloom break, right now 🌷",
            "Your desk misses you already — go stretch 🌼",
            "Two minutes for you, no negotiating 💮",
            "The screen can survive without you for a bit 🌻",
            "Step away, then come back sharper 🌺",
        ].randomElement()!
    }
}

/// The break card's centre content: same header band, disc, fonts and
/// per-flower text colours as CardContentView, but the body's centrepiece
/// is the nudge (title + body) instead of a quote, and the controls are
/// "Took it ✓" / "5 more minutes" instead of refresh/pin/close.
private struct BreakCardContentView: View {
    let nudge: CareNudge
    let flower: Flower?
    var onTookIt: (() -> Void)? = nil
    var onSnooze: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveringClose = false

    private var colors: CardTextColors {
        BloomCatalog.textColors(for: flower?.name ?? "Daisy")
    }
    private var isDark: Bool { colorScheme == .dark }
    private var primary: Color { Color(hex: isDark ? colors.darkPrimary : colors.lightPrimary) }
    private var secondary: Color { Color(hex: isDark ? colors.darkSecondary : colors.lightSecondary) }
    private var cardFill: Color { Color(hex: isDark ? "#241A12" : "#FFFDFA") }
    private var headerTint: Color {
        let hex = BloomCatalog.spec(for: flower?.name ?? "Daisy").outerColorHex
        return Color(hex: hex).opacity(isDark ? 0.38 : 0.30)
    }
    private var buttonTint: Color {
        Color(hex: BloomCatalog.spec(for: flower?.name ?? "Daisy").outerColorHex)
    }
    /// Same petal-coloured rim treatment as the greeting card — hairline
    /// gradient stroke plus close-in glow, so the edge meets the petals
    /// with light instead of a hard white cut.
    private var bloomSpec: BloomSpec { BloomCatalog.spec(for: flower?.name ?? "Daisy") }
    private var rimGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: bloomSpec.outerColorHex).opacity(0.55),
                                Color(hex: bloomSpec.innerColorHex).opacity(0.35)],
                       startPoint: .top, endPoint: .bottom)
    }
    private var glowColor: Color { Color(hex: bloomSpec.outerColorHex).opacity(isDark ? 0.5 : 0.38) }

    // Same centre disc as the greeting card, a size down: a nudge carries
    // far less text, and a disc sized for the greeting would sit half empty.
    private let diameter: CGFloat = 340

    private func capsText(_ s: String) -> Text {
        Text(s.uppercased())
            .font(.custom("Karla", size: 8.5))
            .fontWeight(.medium)
            .tracking(2)
    }

    // Chords of the disc at each block's own height — narrow under the top
    // curve, widest across the middle.
    private let headerTextWidth: CGFloat = 196
    private let bodyTextWidth: CGFloat = 258

    var body: some View {
        VStack(spacing: 0) {
            // ── Header band ── same flower name + Vietnamese annotation as
            // the greeting card, just without the meaning line under it —
            // there's no room to spare above a two-button nudge.
            VStack(spacing: 5) {
                capsText("Take a break")
                    .foregroundColor(secondary)
                if let flower {
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
                }
            }
            .frame(width: headerTextWidth)
            .padding(.top, 34)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity)
            .background(headerTint)

            // ── Body: the nudge, where the quote sits on the greeting card ──
            VStack(spacing: 18) {
                VStack(spacing: 7) {
                    Text(nudge.title.noWidow(font: CardFont.fraunces(19), width: bodyTextWidth))
                        .font(.custom("Fraunces", size: 19))
                        .fontWeight(.semibold)
                        .foregroundColor(primary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                    Text(nudge.body.noWidow(font: CardFont.karla(12), width: bodyTextWidth))
                        .font(.custom("Karla", size: 12))
                        .foregroundColor(secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .frame(width: bodyTextWidth)

                HStack(spacing: 12) {
                    breakButton("Took it ✓", action: onTookIt)
                    breakButton("5 more minutes", action: onSnooze)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .background(
            Circle()
                .fill(cardFill)
                .shadow(color: glowColor, radius: 12, x: 0, y: 0)
                .shadow(color: buttonTint.opacity(isDark ? 0.35 : 0.16), radius: 20, x: 0, y: 6)
        )
        .overlay(
            Circle().stroke(rimGradient, lineWidth: 1.5)
                .allowsHitTesting(false)
        )
        // No ↺/pin here — a break nudge isn't something to refresh or pin.
        // × behaves like Esc (the caller treats them identically), so it
        // gets the same quiet styling the greeting card's controls use.
        .overlay(alignment: .top) {
            VStack(spacing: 3) {
                Button { onClose?() } label: {
                    Image(systemName: "xmark")
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5, weight: .semibold))
                .onHover { hoveringClose = $0 }
                if hoveringClose {
                    Text("Back in 10 minutes")
                        .font(.custom("Karla", size: 9))
                        .tracking(0.4)
                        .transition(.opacity)
                }
            }
            .foregroundColor(secondary)
            .opacity(hoveringClose ? 1 : 0.8)
            .animation(.easeOut(duration: 0.12), value: hoveringClose)
            .padding(.top, 14)
        }
    }

    /// Soft-pressure capsule, quiet Karla — a nudge, not an alarm.
    private func breakButton(_ title: String, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            Text(title)
                .font(.custom("Karla", size: 12))
                .fontWeight(.medium)
                .foregroundColor(primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(buttonTint.opacity(isDark ? 0.22 : 0.16))
                        .overlay(Capsule().strokeBorder(buttonTint.opacity(0.5), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }
}

/// The break card's full popover content: same bloom-behind-disc
/// composition, same 640x640 frame, as FlowerCardView — the panel doesn't
/// need to change shape between a greeting and a break nudge. It follows
/// the same card scale for that reason: the panel is shared, so a break
/// card left at 1x would sit mis-sized inside a resized panel.
struct BreakCardView: View {
    let nudge: CareNudge
    let flower: Flower?
    let toastText: String
    @ObservedObject var scaleState: CardScaleState
    var onTookIt: (() -> Void)? = nil
    var onSnooze: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil

    private var toastTint: Color {
        Color(hex: BloomCatalog.spec(for: flower?.name ?? "Daisy").outerColorHex)
    }

    var body: some View {
        ZStack {
            BloomView(spec: BloomCatalog.spec(for: flower?.name ?? "Daisy"))
            BreakCardContentView(nudge: nudge, flower: flower, onTookIt: onTookIt, onSnooze: onSnooze, onClose: onClose)
        }
        .frame(width: CardScaleState.baseSize, height: CardScaleState.baseSize)
        .overlay(alignment: .top) {
            GiftToast(text: toastText, tint: toastTint)
                .padding(.top, 56)
                .allowsHitTesting(false)
        }
        .cardScaled(scaleState.scale)
    }
}
