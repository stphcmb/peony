import SwiftUI
import PositiveVibeOnlyCore

/// The centre "lens" card, sitting on top of the day's bloom. Content order:
/// greeting + date, flower name + sentence, a dash, quote + author, a dash,
/// the day's prompt, then a short encouragement as the closing line.
/// Text colour hue tracks the flower; only lightness changes between light
/// and dark mode.
struct CardContentView: View {
    let greeting: Greeting
    let name: String?
    let updateAvailable: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    private var colors: CardTextColors {
        BloomCatalog.textColors(for: greeting.flower?.name ?? "Daisy")
    }
    private var isDark: Bool { colorScheme == .dark }
    private var primary: Color { Color(hex: isDark ? colors.darkPrimary : colors.lightPrimary) }
    private var secondary: Color { Color(hex: isDark ? colors.darkSecondary : colors.lightSecondary) }
    private var muted: Color { Color(hex: isDark ? colors.darkMuted : colors.lightMuted) }
    private var dash: Color { Color(hex: isDark ? colors.darkDash : colors.lightDash) }
    private var cardFill: Color { Color(hex: isDark ? "#241A12" : "#FFFDFA") }

    private var greetingLine: String {
        guard let name, !name.isEmpty else { return "Hello" }
        return "Hi \(name)"
    }

    private func dashDivider() -> some View {
        RoundedRectangle(cornerRadius: 999)
            .fill(dash)
            .frame(width: 22, height: 2)
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 2) {
                Text(greetingLine)
                    .font(.custom("Fraunces", size: 19))
                    .foregroundColor(primary)
                Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.custom("Fraunces", size: 13))
                    .italic()
                    .foregroundColor(secondary)
            }

            if let flower = greeting.flower {
                VStack(spacing: 6) {
                    Text(flower.name)
                        .font(.custom("Fraunces", size: 28))
                        .tracking(-0.4)
                        .foregroundColor(primary)
                    Text(flower.meaning)
                        .font(.custom("Karla", size: 13.5))
                        .foregroundColor(secondary)
                        .multilineTextAlignment(.center)
                }
                dashDivider()
            }

            VStack(spacing: 4) {
                Text("\u{201C}\(greeting.quote.text)\u{201D}")
                    .font(.custom("Fraunces", size: 17))
                    .italic()
                    .fontWeight(.light)
                    .foregroundColor(primary)
                    .multilineTextAlignment(.center)
                Text(greeting.quote.author)
                    .font(.custom("Karla", size: 12.5))
                    .foregroundColor(muted)
            }

            dashDivider()

            VStack(spacing: 3) {
                Text(greeting.prompt.title)
                    .font(.custom("Fraunces", size: 15))
                    .foregroundColor(primary)
                    .multilineTextAlignment(.center)
                Text(greeting.prompt.body)
                    .font(.custom("Karla", size: 12.5))
                    .foregroundColor(secondary)
                    .multilineTextAlignment(.center)
            }

            Text(greeting.compliment)
                .font(.custom("Karla", size: 13.5))
                .foregroundColor(primary)
                .multilineTextAlignment(.center)

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
                .font(.custom("Karla", size: 10))
                .foregroundColor(muted.opacity(0.75))
        }
        .padding(.top, 34)
        .padding(.horizontal, 30)
        .padding(.bottom, 36)
        .frame(width: 258)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            LensShape(radiusX: 122, radiusY: 92)
                .fill(cardFill)
                .shadow(color: shadowColor, radius: 20, x: 0, y: 6)
        )
    }

    /// "v1.0.3 · updated Aug 14, 2026". Version comes from the bundle the
    /// app is actually running from; the date is stamped into Info.plist by
    /// build-app.sh. Under `swift run` (no bundle plist) it shows "dev".
    private var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "dev"
        if let built = info?["PeonyBuildDate"] as? String {
            return "v\(version) · updated \(built)"
        }
        return "v\(version)"
    }

    private var shadowColor: Color {
        guard let flower = greeting.flower else { return .black.opacity(0.16) }
        return Color(hex: BloomCatalog.spec(for: flower.name).outerColorHex).opacity(isDark ? 0.35 : 0.16)
    }
}

/// The full popover content: today's bloom behind, the lens card centred
/// on top, in a fixed 640x640 frame per the approved handoff spec.
struct FlowerCardView: View {
    let greeting: Greeting?
    let name: String?
    @ObservedObject var updateState: UpdateState
    var onDragChanged: ((CGSize) -> Void)? = nil
    var onDragEnded: (() -> Void)? = nil

    var body: some View {
        ZStack {
            if let flower = greeting?.flower {
                BloomView(spec: BloomCatalog.spec(for: flower.name))
            }
            if let greeting {
                CardContentView(greeting: greeting, name: name, updateAvailable: updateState.isAvailable)
            } else {
                Text("Could not load today's content.")
                    .font(.custom("Karla", size: 13))
                    .foregroundColor(.secondary)
                    .padding(24)
                    .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .frame(width: 640, height: 640)
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
