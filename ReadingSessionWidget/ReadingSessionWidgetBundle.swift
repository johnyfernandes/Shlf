//
//  ReadingSessionWidgetBundle.swift
//  ReadingSessionWidget
//
//  Created by João Fernandes on 27/11/2025.
//

import WidgetKit
import SwiftUI

@main
struct ReadingSessionWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReadingSessionWidget()
        ReadingSessionWidgetControl()
        ReadingSessionWidgetLiveActivity()
    }
}
