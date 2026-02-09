//
//  WatchAppLanguage.swift
//  ShlfWatch Watch App
//
//  Created by João Fernandes on 09/02/2026.
//

import SwiftUI

enum WatchAppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case german = "de"
    case french = "fr"
    case portuguese = "pt-PT"
    case spanish = "es"

    var id: String { rawValue }

    var displayNameKey: LocalizedStringKey {
        switch self {
        case .system:
            return "Watch.Language.System"
        case .english:
            return "Watch.Language.English"
        case .german:
            return "Watch.Language.German"
        case .french:
            return "Watch.Language.French"
        case .portuguese:
            return "Watch.Language.Portuguese"
        case .spanish:
            return "Watch.Language.Spanish"
        }
    }

    var locale: Locale? {
        switch self {
        case .system:
            return nil
        case .english:
            return Locale(identifier: "en")
        case .german:
            return Locale(identifier: "de")
        case .french:
            return Locale(identifier: "fr")
        case .portuguese:
            return Locale(identifier: "pt-PT")
        case .spanish:
            return Locale(identifier: "es")
        }
    }
}
