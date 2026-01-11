#if DEBUG
import Foundation
import SwiftData

enum MockSeedRange: String, CaseIterable, Identifiable {
    case week = "1 Week"
    case month = "30 Days"
    case sixMonths = "6 Months"
    case year = "1 Year"

    var id: String { rawValue }

    var dayCount: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .sixMonths: return 180
        case .year: return 365
        }
    }

    var baseBookCount: Int {
        switch self {
        case .week: return 6
        case .month: return 12
        case .sixMonths: return 22
        case .year: return 34
        }
    }

    var streakBounds: ClosedRange<Int> {
        switch self {
        case .week: return 4...7
        case .month: return 8...21
        case .sixMonths: return 14...35
        case .year: return 21...60
        }
    }
}

enum MockSeedIntensity: String, CaseIterable, Identifiable {
    case light = "Light"
    case balanced = "Balanced"
    case dense = "Dense"

    var id: String { rawValue }

    var bookMultiplier: Double {
        switch self {
        case .light: return 0.8
        case .balanced: return 1.0
        case .dense: return 1.35
        }
    }

    var dailyReadingChance: Double {
        switch self {
        case .light: return 0.45
        case .balanced: return 0.6
        case .dense: return 0.75
        }
    }

    var sessionsPerDayRange: ClosedRange<Int> {
        switch self {
        case .light: return 1...2
        case .balanced: return 1...3
        case .dense: return 2...4
        }
    }

    var pagesPerSessionRange: ClosedRange<Int> {
        switch self {
        case .light: return 6...18
        case .balanced: return 10...28
        case .dense: return 16...40
        }
    }

    var dailyPageRange: ClosedRange<Int> {
        switch self {
        case .light: return 12...30
        case .balanced: return 18...45
        case .dense: return 28...70
        }
    }

    var minutesPerPageRange: ClosedRange<Double> {
        switch self {
        case .light: return 2.5...4.0
        case .balanced: return 2.0...3.5
        case .dense: return 1.6...3.0
        }
    }

    var quickSessionChance: Double {
        switch self {
        case .light: return 0.12
        case .balanced: return 0.18
        case .dense: return 0.22
        }
    }
}

struct MockSeedConfiguration {
    let range: MockSeedRange
    let intensity: MockSeedIntensity
    let includePardon: Bool
}

struct MockSeedSummary: Codable, Equatable {
    let seededAt: Date
    let rangeLabel: String
    let intensityLabel: String
    let bookCount: Int
    let sessionCount: Int
    let achievementCount: Int
    let streakEventCount: Int
}

struct MockDataRegistry: Codable {
    var summary: MockSeedSummary
    var bookIDs: [UUID]
    var sessionIDs: [UUID]
    var achievementIDs: [UUID]
    var streakEventIDs: [UUID]
}

final class MockDataStore {
    static let shared = MockDataStore()

    private let defaults: UserDefaults
    private let storageKey = "mockDataRegistry.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> MockDataRegistry? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(MockDataRegistry.self, from: data)
    }

    func save(_ registry: MockDataRegistry) {
        guard let data = try? JSONEncoder().encode(registry) else { return }
        defaults.set(data, forKey: storageKey)
    }

    func clear() {
        defaults.removeObject(forKey: storageKey)
    }

    var summary: MockSeedSummary? {
        load()?.summary
    }
}

enum MockDataError: LocalizedError {
    case insufficientCovers(found: Int, required: Int)
    case missingProfile
    case noReadableBooks

    var errorDescription: String? {
        switch self {
        case .insufficientCovers(let found, let required):
            return "Only found \(found) books with covers (need \(required)). Check network and try again."
        case .missingProfile:
            return "Could not create a user profile for seeding."
        case .noReadableBooks:
            return "No readable books available to create sessions."
        }
    }
}

@MainActor
final class MockDataGenerator {
    private struct SeedBookState {
        let book: Book
        let totalPages: Int
        var currentPage: Int
        var firstSessionDate: Date?
        var lastSessionDate: Date?
    }

    private let modelContext: ModelContext
    private let calendar: Calendar
    private let bookService: BookAPIService
    private let store: MockDataStore

    private let searchQueries: [String] = [
        "Dune",
        "Atomic Habits",
        "Harry Potter",
        "The Hobbit",
        "1984",
        "The Great Gatsby",
        "Pride and Prejudice",
        "To Kill a Mockingbird",
        "The Alchemist",
        "Sapiens",
        "Project Hail Mary",
        "The Silent Patient",
        "Educated Tara Westover",
        "Becoming Michelle Obama",
        "The Martian",
        "Normal People",
        "The Midnight Library",
        "Where the Crawdads Sing",
        "It Ends with Us",
        "The Name of the Wind",
        "The Four Agreements",
        "The Psychology of Money",
        "The Power of Habit",
        "Thinking Fast and Slow"
    ]

    init(
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) {
        self.modelContext = modelContext
        self.calendar = calendar
        self.bookService = BookAPIService()
        self.store = MockDataStore.shared
    }

    func generate(
        configuration: MockSeedConfiguration,
        onProgress: @escaping (String) -> Void
    ) async throws -> MockSeedSummary {
        onProgress("Clearing existing data...")
        try clearAllReadingData()

        let profile = try fetchOrCreateProfile()
        profile.lastReadingDate = nil
        profile.lastPardonDate = nil
        profile.currentStreak = 0
        profile.longestStreak = 0

        let targetBookCount = max(4, Int(Double(configuration.range.baseBookCount) * configuration.intensity.bookMultiplier))
        onProgress("Fetching book covers...")
        let bookInfos = try await fetchBookInfos(count: targetBookCount, onProgress: onProgress)

        onProgress("Creating books...")
        var bookStates = createBooks(from: bookInfos, range: configuration.range)

        onProgress("Building sessions...")
        let sessionResult = createSessions(
            for: &bookStates,
            configuration: configuration
        )

        let streakEventIDs = createStreakEvents(
            from: sessionResult.readingDays,
            pardonDay: sessionResult.pardonDay,
            configuration: configuration,
            profile: profile
        )
        if !configuration.includePardon {
            profile.lastPardonDate = nil
        }

        onProgress("Finalizing stats...")
        let engine = GamificationEngine(modelContext: modelContext)
        engine.recalculateStats(for: profile)

        let achievements = try fetchAchievements()
        achievements.forEach { $0.isNew = false }
        try modelContext.save()

        let summary = MockSeedSummary(
            seededAt: Date(),
            rangeLabel: configuration.range.rawValue,
            intensityLabel: configuration.intensity.rawValue,
            bookCount: bookStates.count,
            sessionCount: sessionResult.sessionIDs.count,
            achievementCount: achievements.count,
            streakEventCount: streakEventIDs.count
        )

        let registry = MockDataRegistry(
            summary: summary,
            bookIDs: bookStates.map { $0.book.id },
            sessionIDs: sessionResult.sessionIDs,
            achievementIDs: achievements.map { $0.id },
            streakEventIDs: streakEventIDs
        )
        store.save(registry)

        return summary
    }

    func clearMockData() throws -> MockSeedSummary? {
        guard let registry = store.load() else { return nil }

        let bookIDs = Set(registry.bookIDs)
        let sessionIDs = Set(registry.sessionIDs)
        let achievementIDs = Set(registry.achievementIDs)
        let streakEventIDs = Set(registry.streakEventIDs)

        let books = try modelContext.fetch(FetchDescriptor<Book>())
        books.filter { bookIDs.contains($0.id) }.forEach { modelContext.delete($0) }

        let sessions = try modelContext.fetch(FetchDescriptor<ReadingSession>())
        sessions.filter { sessionIDs.contains($0.id) }.forEach { modelContext.delete($0) }

        let achievements = try modelContext.fetch(FetchDescriptor<Achievement>())
        achievements.filter { achievementIDs.contains($0.id) }.forEach { modelContext.delete($0) }

        let streakEvents = try modelContext.fetch(FetchDescriptor<StreakEvent>())
        streakEvents.filter { streakEventIDs.contains($0.id) }.forEach { modelContext.delete($0) }

        try modelContext.save()
        store.clear()

        if let profile = try? fetchOrCreateProfile() {
            let engine = GamificationEngine(modelContext: modelContext)
            engine.recalculateStats(for: profile)
        }

        return registry.summary
    }

    private func clearAllReadingData() throws {
        try deleteAll(Book.self)
        try deleteAll(ReadingSession.self)
        try deleteAll(Achievement.self)
        try deleteAll(StreakEvent.self)
        try deleteAll(ActiveReadingSession.self)
        try deleteAll(BookPosition.self)
        try deleteAll(Quote.self)
        try modelContext.save()
        store.clear()
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        let items = try modelContext.fetch(descriptor)
        for item in items {
            modelContext.delete(item)
        }
    }

    private func fetchOrCreateProfile() throws -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        if let profile = try modelContext.fetch(descriptor).first {
            return profile
        }
        let profile = UserProfile(hasCompletedOnboarding: true)
        modelContext.insert(profile)
        try modelContext.save()
        return profile
    }

    private func fetchAchievements() throws -> [Achievement] {
        let descriptor = FetchDescriptor<Achievement>()
        return try modelContext.fetch(descriptor)
    }

    private func fetchBookInfos(count: Int, onProgress: @escaping (String) -> Void) async throws -> [BookInfo] {
        var results: [BookInfo] = []
        var seen: Set<String> = []

        let queries = searchQueries.shuffled()
        for query in queries {
            if results.count >= count { break }
            onProgress("Searching \(query)...")

            let searchResults = try await bookService.searchBooks(query: query)
            let filtered = searchResults.filter { info in
                info.coverImageURL != nil && !info.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

            for info in filtered.shuffled() {
                guard seen.insert(info.stableID).inserted else { continue }
                results.append(info)
                if results.count >= count { break }
            }
        }

        if results.count < max(3, min(count, 6)) {
            throw MockDataError.insufficientCovers(found: results.count, required: count)
        }

        return Array(results.prefix(count))
    }

    private func createBooks(from infos: [BookInfo], range: MockSeedRange) -> [SeedBookState] {
        let today = calendar.startOfDay(for: Date())
        let rangeStart = calendar.date(byAdding: .day, value: -(range.dayCount - 1), to: today) ?? today
        let addedStart = calendar.date(byAdding: .day, value: -30, to: rangeStart) ?? rangeStart

        var states: [SeedBookState] = []
        for info in infos {
            let totalPages = info.totalPages ?? {
                let isShort = Double.random(in: 0...1) < 0.25
                return isShort ? Int.random(in: 140...220) : Int.random(in: 220...520)
            }()
            let dateAdded = randomDate(between: addedStart, and: today)

            let book = Book(
                title: info.title,
                author: info.author,
                isbn: info.isbn,
                coverImageURL: info.coverImageURL,
                totalPages: totalPages,
                currentPage: 0,
                bookType: randomBookType(),
                readingStatus: .wantToRead,
                dateAdded: dateAdded,
                notes: "",
                rating: nil,
                bookDescription: info.description,
                subjects: info.subjects,
                publisher: info.publisher,
                publishedDate: info.publishedDate,
                language: info.language,
                openLibraryWorkID: info.workID,
                openLibraryEditionID: info.olid
            )
            modelContext.insert(book)

            let state = SeedBookState(
                book: book,
                totalPages: max(totalPages, 1),
                currentPage: 0,
                firstSessionDate: nil,
                lastSessionDate: nil
            )
            states.append(state)
        }

        return states
    }

    private func createSessions(
        for states: inout [SeedBookState],
        configuration: MockSeedConfiguration
    ) -> (sessionIDs: [UUID], readingDays: Set<Date>, pardonDay: Date?) {
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -(configuration.range.dayCount - 1), to: today) ?? today

        var days: [Date] = []
        for offset in 0..<configuration.range.dayCount {
            if let day = calendar.date(byAdding: .day, value: offset, to: startDate) {
                days.append(day)
            }
        }

        let availableBooks = Array(states.indices)
        let unreadCount = max(1, Int(Double(states.count) * 0.2))
        let unreadIndices = Set(availableBooks.shuffled().prefix(unreadCount))

        let streakBounds = configuration.range.streakBounds
        let maxStreak = min(streakBounds.upperBound, days.count)
        let minStreak = min(streakBounds.lowerBound, maxStreak)
        let streakLength = maxStreak > 0 ? Int.random(in: minStreak...maxStreak) : 0
        let streakStartIndex = max(0, days.count - streakLength)

        let pardonDay: Date? = {
            guard configuration.includePardon, streakLength >= 5 else { return nil }
            let eligible = days[streakStartIndex..<(days.count - 1)]
            return eligible.randomElement()
        }()

        let recentDayCount = min(3, days.count)
        let recentDays = Set(days.suffix(recentDayCount).map { calendar.startOfDay(for: $0) })
        let effectivePardonDay: Date? = {
            guard let pardonDay else { return nil }
            let normalized = calendar.startOfDay(for: pardonDay)
            return recentDays.contains(normalized) ? nil : normalized
        }()

        var readingPlan = days.enumerated().map { index, day -> Bool in
            let isStreakDay = index >= streakStartIndex
            if isStreakDay {
                return calendar.startOfDay(for: day) != calendar.startOfDay(for: effectivePardonDay ?? Date.distantPast)
            }
            return Double.random(in: 0...1) < configuration.intensity.dailyReadingChance
        }

        if !readingPlan.isEmpty {
            for offset in 0..<recentDayCount {
                readingPlan[readingPlan.count - 1 - offset] = true
            }
        }

        let readingDayCount = max(1, readingPlan.filter { $0 }.count)
        let totalReadablePages = states.enumerated().reduce(0) { partial, entry in
            let (index, state) = entry
            return unreadIndices.contains(index) ? partial : partial + state.totalPages
        }
        let targetTotalPages = Int(Double(totalReadablePages) * 0.7)
        var remainingTargetPages = max(0, targetTotalPages)

        var sessionIDs: [UUID] = []
        var readingDays: Set<Date> = []

        for (index, day) in days.enumerated() {
            let shouldRead = readingPlan[index]

            guard shouldRead else { continue }

            let remainingDays = max(1, readingPlan[index...].filter { $0 }.count)
            let averageRemaining = max(4, remainingTargetPages / remainingDays)
            let dailyRange = configuration.intensity.dailyPageRange
            var dailyBudget = min(dailyRange.upperBound, max(averageRemaining, 4))
            dailyBudget = max(4, Int(Double(dailyBudget) * Double.random(in: 0.75...1.25)))

            let sessionsToday = Int.random(in: configuration.intensity.sessionsPerDayRange)
            var sessionsCreatedToday = 0
            for _ in 0..<sessionsToday {
                guard let bookIndex = pickReadableBookIndex(from: states, excluding: unreadIndices) else { break }
                let isQuick = Double.random(in: 0...1) < configuration.intensity.quickSessionChance
                let pageRange = isQuick ? 1...4 : configuration.intensity.pagesPerSessionRange

                var state = states[bookIndex]
                let remaining = max(0, state.totalPages - state.currentPage)
                guard remaining > 0 else { continue }

                if dailyBudget <= 0, sessionsCreatedToday > 0 { break }

                var pagesToRead = min(remaining, Int.random(in: pageRange))
                if dailyBudget > 0 {
                    pagesToRead = min(pagesToRead, dailyBudget)
                } else if sessionsCreatedToday == 0 {
                    pagesToRead = min(remaining, min(6, max(2, dailyRange.lowerBound / 3)))
                }
                guard pagesToRead > 0 else { continue }

                let startPage = state.currentPage
                let endPage = startPage + pagesToRead

                let minutesPerPage = Double.random(in: configuration.intensity.minutesPerPageRange)
                let durationMinutes = max(5, Int(Double(pagesToRead) * minutesPerPage))

                let startDate = randomSessionStart(on: day, durationMinutes: durationMinutes)
                let endDate = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))

                let session = ReadingSession(
                    startDate: startDate,
                    endDate: endDate,
                    startPage: startPage,
                    endPage: endPage,
                    durationMinutes: durationMinutes,
                    xpEarned: 0,
                    isAutoGenerated: isQuick,
                    countsTowardStats: true,
                    isImported: false,
                    book: state.book
                )
                session.xpEarned = XPCalculator.calculate(for: session)
                session.xpAwarded = true
                modelContext.insert(session)
                sessionIDs.append(session.id)
                sessionsCreatedToday += 1

                state.currentPage = endPage
                state.firstSessionDate = state.firstSessionDate ?? startDate
                state.lastSessionDate = endDate
                states[bookIndex] = state

                if dailyBudget > 0 {
                    dailyBudget = max(0, dailyBudget - pagesToRead)
                }
                if remainingTargetPages > 0 {
                    remainingTargetPages = max(0, remainingTargetPages - pagesToRead)
                }
            }

            if sessionsCreatedToday > 0 {
                readingDays.insert(calendar.startOfDay(for: day))
            }
        }

        finalizeBooks(&states, unreadIndices: unreadIndices)
        return (sessionIDs, readingDays, effectivePardonDay)
    }

    private func createStreakEvents(
        from readingDays: Set<Date>,
        pardonDay: Date?,
        configuration: MockSeedConfiguration,
        profile: UserProfile
    ) -> [UUID] {
        guard configuration.includePardon, let pardonDay, !readingDays.isEmpty else { return [] }

        let normalizedPardonDay = calendar.startOfDay(for: pardonDay)

        let event = StreakEvent(
            date: normalizedPardonDay,
            type: .saved,
            streakLength: max(3, min(30, configuration.range.dayCount / 3))
        )
        modelContext.insert(event)

        profile.lastPardonDate = normalizedPardonDay

        return [event.id]
    }

    private func finalizeBooks(_ states: inout [SeedBookState], unreadIndices: Set<Int>) {
        for index in states.indices {
            var state = states[index]
            let book = state.book
            let totalPages = state.totalPages

            if unreadIndices.contains(index) || state.currentPage == 0 {
                book.readingStatus = .wantToRead
                book.currentPage = 0
                book.dateStarted = nil
                book.dateFinished = nil
                state.currentPage = 0
            } else if state.currentPage >= totalPages {
                book.readingStatus = .finished
                book.currentPage = totalPages
                book.dateStarted = state.firstSessionDate
                book.dateFinished = state.lastSessionDate
                book.rating = Int.random(in: 3...5)
                state.currentPage = totalPages
            } else {
                book.readingStatus = .currentlyReading
                book.currentPage = state.currentPage
                book.dateStarted = state.firstSessionDate
                book.dateFinished = nil
            }

            if let started = book.dateStarted, book.dateAdded > started {
                book.dateAdded = calendar.date(byAdding: .day, value: -Int.random(in: 1...10), to: started) ?? started
            }

            states[index] = state
        }

        if states.allSatisfy({ $0.book.readingStatus != .currentlyReading }) {
            if let candidateIndex = states.indices.randomElement() {
                var state = states[candidateIndex]
                let book = state.book
                let totalPages = state.totalPages
                let current = max(10, min(totalPages - 10, totalPages / 3))
                book.readingStatus = .currentlyReading
                book.currentPage = current
                book.dateStarted = state.firstSessionDate ?? book.dateAdded
                book.dateFinished = nil
                state.currentPage = current
                states[candidateIndex] = state
            }
        }
    }

    private func pickReadableBookIndex(from states: [SeedBookState], excluding unreadIndices: Set<Int>) -> Int? {
        let readable = states.indices.filter { index in
            if unreadIndices.contains(index) { return false }
            return states[index].currentPage < states[index].totalPages
        }
        return readable.randomElement()
    }

    private func randomDate(between start: Date, and end: Date) -> Date {
        let interval = max(0, end.timeIntervalSince(start))
        let offset = TimeInterval.random(in: 0...interval)
        return start.addingTimeInterval(offset)
    }

    private func randomSessionStart(on day: Date, durationMinutes: Int) -> Date {
        let startOfDay = calendar.startOfDay(for: day)
        let latestHour = max(8, 22 - Int(ceil(Double(durationMinutes) / 60.0)))
        let hour = Int.random(in: 7...latestHour)
        let minute = Int.random(in: 0..<60)
        let second = Int.random(in: 0..<60)
        return calendar.date(bySettingHour: hour, minute: minute, second: second, of: startOfDay) ?? startOfDay
    }

    private func randomBookType() -> BookType {
        let roll = Double.random(in: 0...1)
        switch roll {
        case 0..<0.6:
            return .physical
        case 0.6..<0.85:
            return .ebook
        default:
            return .audiobook
        }
    }
}
#endif
