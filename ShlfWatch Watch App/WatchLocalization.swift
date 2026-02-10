//
//  WatchLocalization.swift
//  ShlfWatch Watch App
//
//  Created by João Fernandes on 09/02/2026.
//

import Foundation

func watchLocalized(_ key: String, locale: Locale) -> String {
    if let bundle = Bundle.watchLocalizedBundle(for: locale) {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
    return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
}

private extension Bundle {
    static func watchLocalizedBundle(for locale: Locale) -> Bundle? {
        let candidates = [locale.identifier, locale.shlfLanguageCode].compactMap { $0 }
        for identifier in candidates {
            if let path = Bundle.main.path(forResource: identifier, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return nil
    }
}

private extension Locale {
    var shlfLanguageCode: String? {
        if #available(watchOS 9.0, *) {
            return language.languageCode?.identifier
        }
        return languageCode
    }
}
