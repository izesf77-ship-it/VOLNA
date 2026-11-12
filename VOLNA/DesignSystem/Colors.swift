import SwiftUI

extension Color {
    // MARK: - Backgrounds
    static let volnaBackground = Color(hex: "07060B")
    static let volnaBackgroundSoft = Color(hex: "0D0B13")
    static let volnaSurface = Color(hex: "14111D")
    static let volnaSurfaceSecondary = Color(hex: "1D1929")
    static let volnaElevated = Color(hex: "272236")

    // MARK: - Accents
    static let volnaPurple = Color(hex: "7C5CFF")
    static let volnaBlue = Color(hex: "3AA0FF")
    static let volnaMagenta = Color(hex: "FF5CA8")
    static let volnaCyan = Color(hex: "5FE3F2")
    static let volnaMint = Color(hex: "27D796")
    static let volnaAmber = Color(hex: "F5B84B")

    // MARK: - Text
    static let volnaTextPrimary = Color.white.opacity(0.96)
    static let volnaTextSecondary = Color.white.opacity(0.64)
    static let volnaTextTertiary = Color.white.opacity(0.40)

    // MARK: - Semantic
    static let volnaSuccess = Color(hex: "35D07F")
    static let volnaWarning = Color(hex: "F5B84B")
    static let volnaError = Color(hex: "FF6B6B")

    // MARK: - Gradients
    static let volnaAccentGradient = LinearGradient(
        colors: [volnaPurple, volnaBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let volnaRussianGradient = LinearGradient(
        colors: [Color(hex: "7C5CFF"), Color(hex: "FF5CA8")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let volnaWarmGradient = LinearGradient(
        colors: [Color(hex: "F5B84B"), Color(hex: "FF7A59")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let volnaCoolGradient = LinearGradient(
        colors: [Color(hex: "3AA0FF"), Color(hex: "5FE3F2")],
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

struct VolnaBackground: View {
    var body: some View {
        ZStack {
            Color.volnaBackground

            Circle()
                .fill(Color.volnaPurple.opacity(0.20))
                .frame(width: 460, height: 460)
                .blur(radius: 130)
                .offset(x: -170, y: -300)

            Circle()
                .fill(Color.volnaBlue.opacity(0.15))
                .frame(width: 420, height: 420)
                .blur(radius: 140)
                .offset(x: 190, y: -120)

            Circle()
                .fill(Color.volnaMagenta.opacity(0.08))
                .frame(width: 320, height: 320)
                .blur(radius: 120)
                .offset(x: 120, y: 380)

            LinearGradient(
                colors: [Color.clear, Color.volnaBackground.opacity(0.85), Color.volnaBackground],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

extension Font {
    static func volnaDisplay(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func volnaHeadline(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func volnaBody(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
}

// MARK: - Card style

struct VolnaCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 22
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.volnaSurface.opacity(0.78))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    }
            }
    }
}

extension View {
    func volnaCard(cornerRadius: CGFloat = 22, padding: CGFloat = 16) -> some View {
        modifier(VolnaCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    func volnaScreen() -> some View {
        scrollContentBackground(.hidden)
            .background(VolnaBackground())
            .toolbarBackground(Color.volnaBackground.opacity(0.92), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    func volnaBottomInset() -> some View {
        safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 118)
        }
    }
}

struct VolnaPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.volnaPurple, Color.volnaBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct VolnaIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.volnaTextPrimary)
            .frame(width: 42, height: 42)
            .background(Color.white.opacity(0.07))
            .clipShape(Circle())
            .opacity(configuration.isPressed ? 0.65 : 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
