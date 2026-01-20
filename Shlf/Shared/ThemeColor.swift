//
//  ThemeColor.swift
//  Shlf
//
//  Theme color customization
//

import SwiftUI

enum ThemeColor: String, CaseIterable, Codable, Identifiable {
    case neutral = "Neutral"
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case cyan = "Cyan"
    case indigo = "Indigo"
    case teal = "Teal"
    case mint = "Mint"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .neutral:
            return Color.primary
        case .blue:
            return Color(red: 0.0, green: 0.48, blue: 1.0)
        case .purple:
            return Color(red: 0.69, green: 0.32, blue: 0.87)
        case .pink:
            return Color(red: 1.0, green: 0.18, blue: 0.33)
        case .red:
            return Color(red: 1.0, green: 0.27, blue: 0.23)
        case .orange:
            return Color(red: 1.0, green: 0.58, blue: 0.0)
        case .yellow:
            return Color(red: 1.0, green: 0.8, blue: 0.0)
        case .green:
            return Color(red: 0.2, green: 0.78, blue: 0.35)
        case .cyan:
            return Color(red: 0.2, green: 0.78, blue: 0.78)
        case .indigo:
            return Color(red: 0.35, green: 0.34, blue: 0.84)
        case .teal:
            return Color(red: 0.19, green: 0.69, blue: 0.66)
        case .mint:
            return Color(red: 0.0, green: 0.78, blue: 0.75)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var displayNameKey: LocalizedStringKey {
        switch self {
        case .neutral:
            return "Neutral"
        case .blue:
            return "Blue"
        case .purple:
            return "Purple"
        case .pink:
            return "Pink"
        case .red:
            return "Red"
        case .orange:
            return "Orange"
        case .yellow:
            return "Yellow"
        case .green:
            return "Green"
        case .cyan:
            return "Cyan"
        case .indigo:
            return "Indigo"
        case .teal:
            return "Teal"
        case .mint:
            return "Mint"
        }
    }

    func onColor(for scheme: ColorScheme) -> Color {
        if self == .neutral {
            return scheme == .dark ? .black : .white
        }
        return .white
    }
}
