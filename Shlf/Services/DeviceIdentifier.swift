//
//  DeviceIdentifier.swift
//  Shlf
//
//  Created by João Fernandes on 09/02/2026.
//

import Foundation
import UIKit

struct DeviceIdentifier {
    private static let storageKey = "deviceId"

    static func current() -> String {
        if let cached = UserDefaults.standard.string(forKey: storageKey) {
            return cached
        }

        let identifier = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(identifier, forKey: storageKey)
        return identifier
    }
}
