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
        case .book: return String(localized: "Share.Template.Book")
        case .wrap: return String(localized: "Share.Template.Wrap")
        case .streak: return String(localized: "Share.Template.Streak")
        }
    }
}

enum ShareLayoutStyle: String, CaseIterable, Identifiable {
    case classic
    case centered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return String(localized: "Share.Layout.Classic")
        case .centered: return String(localized: "Share.Layout.Centered")
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
        case .last7: return String(localized: "Share.Period.Last7")
        case .last30: return String(localized: "Share.Period.Last30")
        case .year: return String(localized: "Share.Period.ThisYear")
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
        case .paper: return String(localized: "Share.Background.Paper")
        case .paperDark: return String(localized: "Share.Background.PaperDark")
        }
    }
}

struct ShareStatItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let value: String
}

enum ShareContentBlock: String, CaseIterable, Identifiable {
    case hero
    case quote
    case graph
    case stats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hero: return String(localized: "Share.Block.Hero")
        case .quote: return String(localized: "Share.Block.Quote")
        case .graph: return String(localized: "Share.Block.Graph")
        case .stats: return String(localized: "Share.Block.Stats")
        }
    }

    var icon: String {
        switch self {
        case .hero: return "sparkles.rectangle.stack"
        case .quote: return "quote.bubble"
        case .graph: return "chart.line.uptrend.xyaxis"
        case .stats: return "square.grid.2x2"
        }
    }
}

enum ShareGraphStyle: String, CaseIterable, Identifiable {
    case line
    case bars

    var id: String { rawValue }

    var title: String {
        switch self {
        case .line: return String(localized: "Share.GraphStyle.Line")
        case .bars: return String(localized: "Share.GraphStyle.Bars")
        }
    }
}

enum ShareGraphMetric: String, CaseIterable, Identifiable {
    case pages
    case minutes
    case sessions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pages: return String(localized: "Share.GraphMetric.Pages")
        case .minutes: return String(localized: "Share.GraphMetric.Minutes")
        case .sessions: return String(localized: "Share.GraphMetric.Sessions")
        }
    }
}

struct ShareGraph {
    let title: String
    let subtitle: String?
    let values: [Double]
    let style: ShareGraphStyle
}

struct ShareQuote {
    let text: String
    let attribution: String?
}

enum LibraryShareFilter: String, CaseIterable, Identifiable {
    case all
    case finished
    case currentlyReading
    case wantToRead
    case didNotFinish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return String(localized: "Share.Library.Filter.All")
        case .finished: return String(localized: "Share.Library.Filter.Finished")
        case .currentlyReading: return String(localized: "Share.Library.Filter.Reading")
        case .wantToRead: return String(localized: "Share.Library.Filter.WantToRead")
        case .didNotFinish: return String(localized: "Share.Library.Filter.DNF")
        }
    }

    var shareTitle: String {
        switch self {
        case .all: return String(localized: "Share.Library.Title.All")
        case .finished: return String(localized: "Share.Library.Title.Finished")
        case .currentlyReading: return String(localized: "Share.Library.Title.ReadingNow")
        case .wantToRead: return String(localized: "Share.Library.Title.WantToRead")
        case .didNotFinish: return String(localized: "Share.Library.Title.DidNotFinish")
        }
    }

    var status: ReadingStatus? {
        switch self {
        case .all: return nil
        case .finished: return .finished
        case .currentlyReading: return .currentlyReading
        case .wantToRead: return .wantToRead
        case .didNotFinish: return .didNotFinish
        }
    }
}

enum LibraryShareSort: String, CaseIterable, Identifiable {
    case recentlyAdded
    case title
    case author
    case progress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recentlyAdded: return String(localized: "Share.Library.Sort.RecentlyAdded")
        case .title: return String(localized: "Share.Library.Sort.Title")
        case .author: return String(localized: "Share.Library.Sort.Author")
        case .progress: return String(localized: "Share.Library.Sort.Progress")
        }
    }
}

enum LibraryShareGridStyle: String, CaseIterable, Identifiable {
    case large
    case medium
    case compact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .large: return String(localized: "Share.Library.Grid.Large")
        case .medium: return String(localized: "Share.Library.Grid.Medium")
        case .compact: return String(localized: "Share.Library.Grid.Compact")
        }
    }

    var columns: Int {
        switch self {
        case .large: return 2
        case .medium: return 3
        case .compact: return 4
        }
    }

    var rows: Int {
        switch self {
        case .large: return 3
        case .medium: return 4
        case .compact: return 5
        }
    }

    var maxItems: Int {
        columns * rows
    }
}

struct LibraryShareBook: Identifiable {
    let id: UUID
    let title: String
    let author: String
    let status: ReadingStatus
    let coverImage: UIImage?
}

struct LibraryShareContent {
    let title: String
    let subtitle: String?
    let badge: String?
    let books: [LibraryShareBook]
    let overflowCount: Int
    let showOverflow: Bool
    let gridStyle: LibraryShareGridStyle
    let showTitles: Bool
    let showStatus: Bool
    let footer: String
}

struct ShareCardContent {
    let title: String
    let subtitle: String?
    let badge: String?
    let period: String?
    let coverImage: UIImage?
    let progress: Double?
    let progressText: String?
    let showProgressRing: Bool
    let hideProgressRingWhenComplete: Bool
    let quote: ShareQuote?
    let graph: ShareGraph?
    let blocks: [ShareContentBlock]
    let stats: [ShareStatItem]
    let footer: String
}

struct ShareCardStyle {
    let background: ShareBackgroundStyle
    let accentColor: Color
    let layout: ShareLayoutStyle
}
