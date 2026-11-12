import SwiftUI

extension Color {
    // MARK: - Background Colors
    static let volnaBackground = Color(hex: "000000") // Deep black
    static let volnaSurface = Color(hex: "1A1A1A") // Graphite
    static let volnaSurfaceSecondary = Color(hex: "2A2A2A") // Dark gray
    
    // MARK: - Accent Colors
    static let volnaPurple = Color(hex: "8B5CF6") // Deep purple
    static let volnaBlue = Color(hex: "3B82F6") // Blue
    static let volnaMagenta = Color(hex: "EC4899") // Magenta
    static let volnaCyan = Color(hex: "06B6D4") // Cyan
    
    // MARK: - Text Colors
    static let volnaTextPrimary = Color.white
    static let volnaTextSecondary = Color(hex: "A0A0A0") // Light gray
    static let volnaTextTertiary = Color(hex: "6B7280") // Medium gray
    
    // MARK: - Semantic Colors
    static let volnaSuccess = Color(hex: "10B981") // Green
    static let volnaWarning = Color(hex: "F59E0B") // Amber
    static let volnaError = Color(hex: "EF4444") // Red
    
    // MARK: - Helpers
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Gradient Presets
extension LinearGradient {
    static let volnaHero = LinearGradient(
        colors: [.volnaPurple, .volnaBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let volnaAccent = LinearGradient(
        colors: [.volnaBlue, .volnaMagenta],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let volnaSunset = LinearGradient(
        colors: [.volnaMagenta, .volnaPurple, .volnaBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
