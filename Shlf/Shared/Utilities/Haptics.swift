//
//  Haptics.swift
//  Shlf
//
//  Subtle haptic helpers for primary actions.
//

import Foundation

#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        #if canImport(UIKit) && !os(watchOS)
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    static func selection() {
        #if canImport(UIKit) && !os(watchOS)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }
}
