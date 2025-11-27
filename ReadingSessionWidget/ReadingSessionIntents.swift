//
//  ReadingSessionIntents.swift
//  ReadingSessionWidget
//
//  Created by João Fernandes on 27/11/2025.
//

import AppIntents
import ActivityKit

struct IncrementPageIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Increment Page"

    @MainActor
    func perform() async throws -> some IntentResult {
        // Find active reading session activities
        for activity in Activity<ReadingSessionWidgetAttributes>.activities {
            let currentPage = activity.content.state.currentPage + 1
            let pagesRead = currentPage - activity.attributes.startPage
            let xpEarned = pagesRead * 3 // 3 XP per page

            let newState = ReadingSessionWidgetAttributes.ContentState(
                currentPage: currentPage,
                pagesRead: pagesRead,
                xpEarned: xpEarned
            )

            await activity.update(ActivityContent(state: newState, staleDate: nil))
            print("📈 Page incremented to \(currentPage)")
        }

        return .result()
    }
}

struct DecrementPageIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Decrement Page"

    @MainActor
    func perform() async throws -> some IntentResult {
        // Find active reading session activities
        for activity in Activity<ReadingSessionWidgetAttributes>.activities {
            let startPage = activity.attributes.startPage
            let currentPage = max(startPage, activity.content.state.currentPage - 1)
            let pagesRead = max(0, currentPage - startPage)
            let xpEarned = max(0, pagesRead * 3)

            let newState = ReadingSessionWidgetAttributes.ContentState(
                currentPage: currentPage,
                pagesRead: pagesRead,
                xpEarned: xpEarned
            )

            await activity.update(ActivityContent(state: newState, staleDate: nil))
            print("📉 Page decremented to \(currentPage)")
        }

        return .result()
    }
}
