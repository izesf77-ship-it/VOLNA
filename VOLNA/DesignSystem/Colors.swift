import SwiftUI

extension Color {
    // MARK: - Backgrounds (Refined Premium Dark)
    static let volnaBackground = Color(hex: "05050A")
    static let volnaBackgroundSoft = Color(hex: "08070D")
    static let volnaSurface = Color(hex: "101018")
    static let volnaSurfaceSecondary = Color(hex: "161622")
    static let volnaElevated = Color(hex: "1F1F2B")
    static let volnaSurfaceGlass = Color(hex: "15151F").opacity(0.92)
    static let volnaSeparator = Color.white.opacity(0.06)

    // MARK: - Accents (Subtle, premium)
    static let volnaPurple = Color(hex: "7B61FF")
    static let volnaBlue = Color(hex: "4C9BFF")
    static let volnaMagenta = Color(hex: "FF5C9D")
    static let volnaCyan = Color(hex: "5FE7FF")
    static let volnaMint = Color(hex: "32E6A0")
    static let volnaAmber = Color(hex: "FFB63B")
    static let volnaRed = Color(hex: "FF5F5F")

    // MARK: - Text
    static let volnaTextPrimary = Color.white.opacity(0.98)
    static let volnaTextSecondary = Color.white.opacity(0.72)
    static let volnaTextTertiary = Color.white.opacity(0.48)
    static let volnaTextQuaternary = Color.white.opacity(0.32)

    // MARK: - Semantic
    static let volnaSuccess = Color(hex: "32E6A0")
    static let volnaWarning = Color(hex: "FFB63B")
    static let volnaError = Color(hex: "FF5F5F")

    // MARK: - Gradients
    static let volnaAccentGradient = LinearGradient(
        colors: [Color(hex: "7B61FF"), Color(hex: "4C9BFF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let volnaRussianGradient = LinearGradient(
        colors: [Color(hex: "7B61FF"), Color(hex: "FF5C9D")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let volnaWarmGradient = LinearGradient(
        colors: [Color(hex: "FFB63B"), Color(hex: "FF7A3D")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let volnaCoolGradient = LinearGradient(
        colors: [Color(hex: "4C9BFF"), Color(hex: "5FE7FF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let volnaHeroGradient = LinearGradient(
        colors: [Color(hex: "7B61FF").opacity(0.95), Color(hex: "4C9BFF").opacity(0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    init(hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red, green, blue, alpha: Double
        switch cleaned.count {
        case 8:
            red = Double((value >> 24) & 0xFF) / 255
            green = Double((value >> 16) & 0xFF) / 255
            blue = Double((value >> 8) & 0xFF) / 255
            alpha = Double(value & 0xFF) / 255
        case 6:
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
            alpha = 1
        default:
            red = 1
            green = 1
            blue = 1
            alpha = 1
        }
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

// MARK: - Layout Constants

enum VolnaLayout {
    static let horizontalPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 28
    static let itemSpacing: CGFloat = 16
    static let smallSpacing: CGFloat = 12
    static let cardRadius: CGFloat = 20
    static let cardRadiusLarge: CGFloat = 28
    static let cardPadding: CGFloat = 16
    static let buttonHeight: CGFloat = 48
    static let minTouchTarget: CGFloat = 44

    // Tab bar geometry (used for content insets)
    static let tabBarHeight: CGFloat = 66
    static let tabBarBottomMargin: CGFloat = 8
    static let miniPlayerHeight: CGFloat = 68
    static let floatingStackSpacing: CGFloat = 10

    /// Estimated total height of floating bottom UI (mini-player + tab bar + spacing + safe padding)
    static var contentBottomInset: CGFloat {
        // base: tab bar + margin; mini-player adds more when present but we reserve space safely
        tabBarHeight + tabBarBottomMargin + 24
    }

    static var contentBottomInsetWithPlayer: CGFloat {
        miniPlayerHeight + floatingStackSpacing + tabBarHeight + tabBarBottomMargin + 24
    }
}

struct VolnaBackground: View {
    var body: some View {
        ZStack {
            Color.volnaBackground

            // Subtle ambient gradients for depth
            RadialGradient(
                colors: [Color.volnaPurple.opacity(0.18), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 420
            )
            .offset(x: -120, y: -180)

            RadialGradient(
                colors: [Color.volnaBlue.opacity(0.12), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 380
            )
            .offset(x: 120, y: -60)

            RadialGradient(
                colors: [Color.volnaMagenta.opacity(0.06), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 340
            )
            .offset(x: 80, y: 200)

            LinearGradient(
                colors: [Color.clear, Color.volnaBackground.opacity(0.4), Color.volnaBackground.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

enum VolnaFont {
    /// Primary UI font: Onest (variable) with system fallback.
    /// Dynamic Type supported via relativeTo.
    static func custom(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        // "Onest" is the family name for the variable font; fallback to system if unavailable.
        if UIFont(name: "Onest-Regular", size: size) != nil || UIFont.familyNames.contains(where: { $0.localizedCaseInsensitiveContains("Onest") }) {
            return .custom("Onest", size: size, relativeTo: textStyle).weight(weight)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    // Recommended scale
    static let heroTitle = custom(34, weight: .bold, relativeTo: .largeTitle)
    static let screenTitle = custom(30, weight: .bold, relativeTo: .title)
    static let sectionTitle = custom(22, weight: .semibold, relativeTo: .title2)
    static let cardTitle = custom(17, weight: .semibold, relativeTo: .headline)
    static let trackTitle = custom(16, weight: .medium, relativeTo: .headline)
    static let artistTitle = custom(15, weight: .regular, relativeTo: .subheadline)
    static let body = custom(16, weight: .regular, relativeTo: .body)
    static let secondary = custom(14, weight: .regular, relativeTo: .subheadline)
    static let caption = custom(13, weight: .medium, relativeTo: .caption)
    static let tabLabel = custom(11, weight: .medium, relativeTo: .caption2)
}

extension Font {
    // Legacy/compat wrappers (kept for existing call sites)
    static func volnaLargeTitle(_ size: CGFloat = 34) -> Font { VolnaFont.custom(size, weight: .bold, relativeTo: .largeTitle) }
    static func volnaTitle(_ size: CGFloat = 28) -> Font { VolnaFont.custom(size, weight: .bold, relativeTo: .title) }
    static func volnaTitle2(_ size: CGFloat = 22) -> Font { VolnaFont.custom(size, weight: .semibold, relativeTo: .title2) }
    static func volnaTitle3(_ size: CGFloat = 20) -> Font { VolnaFont.custom(size, weight: .semibold, relativeTo: .title3) }
    static func volnaDisplay(_ size: CGFloat) -> Font { VolnaFont.custom(size, weight: .bold, relativeTo: .title) }
    static func volnaHeadline(_ size: CGFloat) -> Font { VolnaFont.custom(size, weight: .semibold, relativeTo: .headline) }
    static func volnaBody(_ size: CGFloat) -> Font { VolnaFont.custom(size, weight: .regular, relativeTo: .body) }

    static let volnaBodyLarge = VolnaFont.custom(17, weight: .regular, relativeTo: .body)
    static let volnaBodyMedium = VolnaFont.custom(15, weight: .regular, relativeTo: .subheadline)
    static let volnaBodySmall = VolnaFont.custom(13, weight: .regular, relativeTo: .footnote)
    static let volnaLabel = VolnaFont.custom(15, weight: .medium, relativeTo: .subheadline)
    static let volnaLabelBold = VolnaFont.custom(15, weight: .semibold, relativeTo: .subheadline)
    static let volnaCaption = VolnaFont.custom(12, weight: .medium, relativeTo: .caption)
    static let volnaCaptionSmall = VolnaFont.custom(11, weight: .medium, relativeTo: .caption2)
    static let volnaMicro = VolnaFont.custom(10, weight: .medium, relativeTo: .caption2)
}

// MARK: - Card style

struct VolnaCardModifier: ViewModifier {
    var cornerRadius: CGFloat = VolnaLayout.cardRadius
    var padding: CGFloat = VolnaLayout.cardPadding
    var style: CardStyle = .elevated

    enum CardStyle {
        case elevated
        case glass
        case flat
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                switch style {
                case .elevated:
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.volnaSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        }
                case .glass:
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(Color.volnaSurface.opacity(0.55))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        }
                case .flat:
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.volnaSurfaceSecondary)
                }
            }
    }
}

extension View {
    func volnaCard(
        cornerRadius: CGFloat = VolnaLayout.cardRadius,
        padding: CGFloat = VolnaLayout.cardPadding,
        style: VolnaCardModifier.CardStyle = .elevated
    ) -> some View {
        modifier(VolnaCardModifier(cornerRadius: cornerRadius, padding: padding, style: style))
    }

    func volnaScreen() -> some View {
        scrollContentBackground(.hidden)
            .background(VolnaBackground())
            .toolbarBackground(Color.volnaBackground.opacity(0.96), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    /// Reserve space for floating tab bar + optional mini player
    func volnaBottomInset(hasPlayer: Bool = false) -> some View {
        safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: hasPlayer ? VolnaLayout.contentBottomInsetWithPlayer : VolnaLayout.contentBottomInset)
                .allowsHitTesting(false)
        }
    }
}

/// Applies screen background and bottom inset that accounts for mini-player/tab bar
struct VolnaScreenModifier: ViewModifier {
    @Environment(AppState.self) private var appState

    func body(content: Content) -> some View {
        content
            .background(VolnaBackground())
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(
                        height: appState.player.currentTrack != nil
                            ? VolnaLayout.contentBottomInsetWithPlayer
                            : VolnaLayout.contentBottomInset
                    )
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func volnaScreenLayout() -> some View {
        modifier(VolnaScreenModifier())
    }
}

struct VolnaPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .default))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(minHeight: 44)
            .background(Color.volnaAccentGradient)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct VolnaSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .default))
            .foregroundStyle(Color.volnaTextPrimary)
            .padding(.horizontal, 20)
            .frame(minHeight: 44)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct VolnaIconButtonStyle: ButtonStyle {
    var size: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.volnaTextPrimary)
            .frame(width: size, height: size)
            .background(Color.white.opacity(0.08))
            .clipShape(Circle())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
