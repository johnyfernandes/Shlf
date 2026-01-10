//
//  ProAccess.swift
//  Shlf
//
//  Centralized Pro entitlement checks and caching.
//

import Foundation

enum ProAccess {
    private static let appGroupId = "group.joaofernandes.Shlf"
    private static let proStatusKey = "proStatusCached"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupId) ?? .standard
    }

    static var cachedIsPro: Bool {
        defaults.bool(forKey: proStatusKey)
    }

    static func setCachedIsPro(_ value: Bool) {
        defaults.set(value, forKey: proStatusKey)
    }

    static func isProUser(profile: UserProfile?) -> Bool {
        StoreKitService.shared.isProUser || profile?.isProUser == true || cachedIsPro
    }
}
