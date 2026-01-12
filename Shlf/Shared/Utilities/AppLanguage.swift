//
//  AppLanguage.swift
//  Shlf
//
//  Created by João Fernandes on 12/01/2026.
//

import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case german = "de"
    case french = "fr"
    case portuguese = "pt-PT"
    case spanish = "es"

    static let overrideKey = "developerLanguageOverride"

    var id: String { rawValue }

    var displayNameKey: String {
        switch self {
        case .system:
            return "System Default"
        case .english:
            return "English"
        case .german:
            return "German"
        case .french:
            return "French"
        case .portuguese:
            return "Portuguese (Portugal)"
        case .spanish:
            return "Spanish"
        }
    }

    var localeIdentifier: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .german:
            return "de"
        case .french:
            return "fr"
        case .portuguese:
            return "pt-PT"
        case .spanish:
            return "es"
        }
    }

    var locale: Locale? {
        guard let localeIdentifier else { return nil }
        return Locale(identifier: localeIdentifier)
    }
}

extension View {
    @ViewBuilder
    func debugLocale(_ language: AppLanguage?) -> some View {
        #if DEBUG
        if let language, let locale = language.locale {
            self.environment(\.locale, locale)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
