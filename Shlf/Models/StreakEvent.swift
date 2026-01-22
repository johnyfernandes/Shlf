//
//  StreakEvent.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import Foundation
import SwiftData

enum StreakEventType: String, Codable, CaseIterable {
    case day
    case saved
    case lost
    case started
}

@Model
final class StreakEvent {
    var id: UUID = UUID()
    var date: Date = Date()
    var typeRawValue: String = StreakEventType.started.rawValue
    var streakLength: Int = 0

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        type: StreakEventType,
        streakLength: Int = 0
    ) {
        self.id = id
        self.date = date
        self.typeRawValue = type.rawValue
        self.streakLength = streakLength
    }

    var type: StreakEventType {
        get { StreakEventType(rawValue: typeRawValue) ?? .started }
        set { typeRawValue = newValue.rawValue }
    }
}
