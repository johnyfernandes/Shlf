//
//  ShareModels.swift
//  Shlf
//
//  Created by Codex on 03/02/2026.
//

import SwiftUI

enum ShareTemplate: String, CaseIterable, Identifiable {
    case book
    case wrap
    case streak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .book: return "Book"
        case .wrap: return "Wrap"
        case .streak: return "Streak"
        }
    }
}

enum SharePeriod: String, CaseIterable, Identifiable {
    case last7
    case last30
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last7: return "Last 7 Days"
        case .last30: return "Last 30 Days"
        case .year: return "This Year"
        }
    }

    func dateRange(from now: Date = Date()) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let end = now
        switch self {
        case .last7:
            let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
            return (start, end)
        case .last30:
            let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)) ?? now
            return (start, end)
        case .year:
            let year = calendar.component(.year, from: now)
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
            return (start, end)
        }
    }
}

enum ShareBackgroundStyle: String, CaseIterable, Identifiable {
    case paper
    case paperDark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paper: return "Paper"
        case .paperDark: return "Paper Dark"
        }
    }
}

struct ShareStatItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let value: String
}

enum ShareGraphMetric: String, CaseIterable, Identifiable {
    case pages
    case minutes
    case sessions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pages: return "Pages"
        case .minutes: return "Minutes"
        case .sessions: return "Sessions"
        }
    }
}

struct ShareGraph {
    let title: String
    let subtitle: String?
    let values: [Double]
}

struct ShareCardContent {
    let title: String
    let subtitle: String?
    let badge: String?
    let period: String?
    let coverImage: UIImage?
    let progress: Double?
    let progressText: String?
    let graph: ShareGraph?
    let stats: [ShareStatItem]
    let footer: String
}

struct ShareCardStyle {
    let background: ShareBackgroundStyle
    let accentColor: Color
}
