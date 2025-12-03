//
//  ThemeColorEnvironment.swift
//  Shlf
//
//  Dynamic theme color environment
//

import SwiftUI

// Environment key for theme color
private struct ThemeColorKey: EnvironmentKey {
    static let defaultValue: ThemeColor = .blue
}

extension EnvironmentValues {
    var themeColor: ThemeColor {
        get { self[ThemeColorKey.self] }
        set { self[ThemeColorKey.self] = newValue }
    }
}

// View extension for easy access to dynamic colors
extension View {
    func withDynamicTheme(_ themeColor: ThemeColor) -> some View {
        self.environment(\.themeColor, themeColor)
            .tint(themeColor.color)
    }
}

// Dynamic theme colors that respond to environment
struct DynamicTheme {
    @Environment(\.themeColor) private var themeColor

    var primary: Color {
        themeColor.color
    }

    var gradient: LinearGradient {
        themeColor.gradient
    }
}
