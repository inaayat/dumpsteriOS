import SwiftUI

enum Theme {
    @MainActor static var isDark: Bool {
        UITraitCollection.current.userInterfaceStyle == .dark
    }

    // Backgrounds
    static var canvas: Color { Color(hex: "#F5F3F0") }
    static var cardBg: Color { Color(hex: "#FFFFFF") }
    static var cardAlt: Color { Color(hex: "#F0EFED") }
    static var sidebarBg: Color { Color(hex: "#2D2D2D") }

    // Text
    static var textPrimary: Color { Color(hex: "#1A1A1A") }
    static var textSecondary: Color { Color(hex: "#3A3A3A") }
    static var textMuted: Color { Color(hex: "#8A8A8A") }

    // Borders
    static var border: Color { Color(hex: "#E5E3E0") }
    static var cardBorder: Color { Color(hex: "#E5E3E0") }

    // Category Colors
    static var actionColor: Color { Color(hex: "#F15A24") }
    static var actionTint: Color { Color(hex: "#FDDCCC") }
    static var brainstormColor: Color { Color(hex: "#2D8A7E") }
    static var brainstormTint: Color { Color(hex: "#D0F0EC") }
    static var resourceColor: Color { Color(hex: "#7B68EE") }
    static var resourceTint: Color { Color(hex: "#E0DBFC") }

    // Accents
    static var accent: Color { Color(hex: "#3BA99C") }
    static var accentTint: Color { Color(hex: "#C5E8E4") }
    static var warnColor: Color { Color(hex: "#F7941D") }
    static var successColor: Color { Color(hex: "#2D8A7E") }

    // Geometry
    static var cornerRadius: CGFloat { 10 }
    static var cardPadding: CGFloat { 12 }
    static var sectionSpacing: CGFloat { 20 }
    static var itemSpacing: CGFloat { 6 }

    // Helpers
    static func categoryColor(_ category: Category) -> Color {
        switch category {
        case .action: return actionColor
        case .brainstorm: return brainstormColor
        case .resource: return resourceColor
        }
    }

    static func categoryTint(_ category: Category) -> Color {
        switch category {
        case .action: return actionTint
        case .brainstorm: return brainstormTint
        case .resource: return resourceTint
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}

// MARK: - Font Extension

extension Font {
    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String = switch weight {
        case .bold: "Inter-Bold"
        case .semibold: "Inter-SemiBold"
        case .medium: "Inter-Medium"
        default: "Inter-Regular"
        }
        return .custom(name, size: size)
    }
}
