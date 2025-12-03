//
//  LogReadingSessionView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData
import Combine

struct LogReadingSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
    @Query private var profiles: [UserProfile]
    @Query private var activeSessions: [ActiveReadingSession]

    let book: Book

    @State private var startPage: Int
    @State private var endPage: Int
    @State private var durationMinutes = 30
    @State private var sessionDate = Date()
    @State private var useTimer = true
    @State private var timerStartTime: Date?
    @State private var isPaused = false
    @State private var pausedElapsedTime: TimeInterval = 0
    @State private var showDiscardAlert = false
    @State private var showActiveSessionAlert = false
    @State private var pendingActiveSession: ActiveReadingSession?

    // Position tracking
    @State private var shouldSavePosition = false
    @State private var positionPage: Int
    @State private var positionLineText = ""
    @State private var positionNote = ""

    // Quote management
    @State private var showAddQuote = false

    init(book: Book) {
        self.book = book
        _startPage = State(initialValue: book.currentPage)
        _endPage = State(initialValue: book.currentPage)
        _positionPage = State(initialValue: book.currentPage)
    }

    // SINGLE SOURCE OF TRUTH - use active session if exists
    private var activeSession: ActiveReadingSession? {
        activeSessions.first
    }

    private var actualStartPage: Int {
        activeSession?.startPage ?? startPage
    }

    private var actualEndPage: Int {
        activeSession?.currentPage ?? endPage
    }

    private var isTimerActive: Bool {
        activeSession != nil || timerStartTime != nil
    }

    private var pagesRead: Int {
        max(0, actualEndPage - actualStartPage)
    }

    private var hasUnsavedData: Bool {
        isTimerActive || pagesRead > 0
    }

    private var estimatedXP: Int {
        let engine = GamificationEngine(modelContext: modelContext)
        let mockSession = ReadingSession(
            startPage: actualStartPage,
            endPage: actualEndPage,
            durationMinutes: durationMinutes
        )
        return engine.calculateXP(for: mockSession)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reading Progress") {
                    HStack {
                        Text("From Page")
                        Spacer()
                        Text("\(actualStartPage)")
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .trailing)
                    }

                    HStack {
                        Text("To Page")
                        Spacer()
                        if let session = activeSession {
                            TextField("End", value: Binding(
                                get: { session.currentPage },
                                set: { newValue in
                                    session.currentPage = newValue
                                    session.lastUpdated = Date()
                                    try? modelContext.save()
                                    WatchConnectivityManager.shared.sendActiveSessionToWatch(session)
                                    WidgetDataExporter.exportSnapshot(modelContext: modelContext)
                                    Task {
                                        await ReadingSessionActivityManager.shared.updateActivity(
                                            currentPage: newValue,
                                            xpEarned: estimatedXP
                                        )
                                    }
                                    WidgetDataExporter.exportSnapshot(modelContext: modelContext)
                                }
                            ), format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        } else {
                            TextField("End", value: $endPage, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .onChange(of: endPage) { oldValue, newValue in
                                    // Clamp to max pages
                                    if let maxPages = book.totalPages, newValue > maxPages {
                                        endPage = maxPages
                                    }
                                }
                        }
                    }

                    HStack {
                        Image(systemName: "book.pages")
                            .foregroundStyle(themeColor.color)

                        Text("Pages Read")
                        Spacer()
                        Text("\(pagesRead)")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(themeColor.color)
                    }
                }

                Section("Duration") {
                    if activeSession == nil {
                        Toggle("Use Timer", isOn: $useTimer)
                    }

                    if let session = activeSession {
                        VStack(spacing: Theme.Spacing.md) {
                            Text(session.isPaused ? "Paused" : "Reading...")
                                .font(Theme.Typography.headline)
                                .foregroundStyle(session.isPaused ? .orange : themeColor.color)

                            Text("Started on \(session.sourceDevice)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ActiveSessionTimerView(activeSession: session)

                            HStack(spacing: Theme.Spacing.sm) {
                                Button(session.isPaused ? "Resume" : "Pause") {
                                    session.isPaused.toggle()
                                    if session.isPaused {
                                        session.pausedAt = Date()
                                    } else {
                                        if let pausedAt = session.pausedAt {
                                            session.totalPausedDuration += Date().timeIntervalSince(pausedAt)
                                        }
                                        session.pausedAt = nil
                                    }
                                    session.lastUpdated = Date()
                                    try? modelContext.save()
                                    WatchConnectivityManager.shared.sendActiveSessionToWatch(session)
                                    WidgetDataExporter.exportSnapshot(modelContext: modelContext)
                                    Task {
                                        await ReadingSessionActivityManager.shared.updateActivity(
                                            currentPage: session.currentPage,
                                            xpEarned: estimatedXP
                                        )
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(themeColor.color)

                                Button("Finish Session") {
                                    finishActiveSession(session)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(themeColor.color)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                    } else if useTimer {
                        if let startTime = timerStartTime {
                            VStack(spacing: Theme.Spacing.md) {
                                Text(isPaused ? "Paused" : "Reading...")
                                    .font(Theme.Typography.headline)
                                    .foregroundStyle(isPaused ? .orange : themeColor.color)

                                TimerView(startTime: startTime, isPaused: isPaused, pausedElapsedTime: pausedElapsedTime)

                                HStack(spacing: Theme.Spacing.sm) {
                                    Button(isPaused ? "Resume" : "Pause") {
                                        if isPaused {
                                            resumeTimer()
                                        } else {
                                            pauseTimer()
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(themeColor.color)

                                    Button("Finish Session") {
                                        finishSession()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(themeColor.color)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.sm)
                        } else {
                            Button("Start Timer") {
                                startTimer()
                            }
                            .primaryButton(color: themeColor.color)
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        Picker("Duration", selection: $durationMinutes) {
                            Text("15 min").tag(15)
                            Text("30 min").tag(30)
                            Text("45 min").tag(45)
                            Text("60 min").tag(60)
                            Text("90 min").tag(90)
                            Text("120 min").tag(120)
                        }
                        .pickerStyle(.wheel)
                    }
                }

                Section("Mark Stopping Position (Optional)") {
                    Toggle("Save reading position", isOn: $shouldSavePosition)

                    if shouldSavePosition {
                        HStack {
                            Text("Page")
                            Spacer()
                            TextField("Page", value: $positionPage, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }

                        HStack {
                            Text("Line (optional)")
                            Spacer()
                            TextField("Line", text: $positionLineText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }

                        TextField("Note (optional)", text: $positionNote, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }
                .headerProminence(.increased)

                Section("Save Quote") {
                    Button {
                        showAddQuote = true
                    } label: {
                        Label("Add Quote from this Session", systemImage: "quote.bubble")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(themeColor.color)
                }

                Section("Date") {
                    DatePicker("Session Date", selection: $sessionDate, displayedComponents: [.date, .hourAndMinute])
                }

                Section {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Theme.Colors.xpGradient)

                        Text("Estimated XP")
                        Spacer()
                        Text("+\(estimatedXP)")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.xpGradient)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                syncWithLiveActivity()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                syncWithLiveActivity()
            }
            .onChange(of: endPage) { oldValue, newValue in
                // Update Live Activity when page changes during active timer
                if timerStartTime != nil {
                    Task {
                        await ReadingSessionActivityManager.shared.updateActivity(
                            currentPage: newValue,
                            xpEarned: estimatedXP
                        )
                    }
                }
            }
            .navigationTitle("Log Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        hideKeyboard()
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        handleCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSession()
                    }
                    .disabled(pagesRead <= 0 || (useTimer && timerStartTime != nil && !isPaused))
                }
            }
            .interactiveDismissDisabled(hasUnsavedData)
            .alert("Discard Session?", isPresented: $showDiscardAlert) {
                Button("Keep Editing", role: .cancel) {}
                Button("Discard", role: .destructive) {
                    Task {
                        await ReadingSessionActivityManager.shared.endActivity()
                    }
                    dismiss()
                }
            } message: {
                Text("You have unsaved progress. Are you sure you want to discard this reading session?")
            }
            .alert("Active Session Found", isPresented: $showActiveSessionAlert) {
                Button("Cancel", role: .cancel) {
                    pendingActiveSession = nil
                }
                Button("End & Start New", role: .destructive) {
                    if let existing = pendingActiveSession {
                        endExistingSessionAndStartNew(existing)
                    }
                }
            } message: {
                if let existing = pendingActiveSession,
                   let bookTitle = existing.book?.title {
                    Text("There's an active session for \"\(bookTitle)\" started on \(existing.sourceDevice). End it and start a new one?")
                } else {
                    Text("There's already an active reading session. End it and start a new one?")
                }
            }
            .sheet(isPresented: $showAddQuote) {
                AddQuoteView(book: book, prefillPage: endPage)
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func handleCancel() {
        if hasUnsavedData {
            showDiscardAlert = true
        } else {
            dismiss()
        }
    }

    private func endExistingSessionAndStartNew(_ existingSession: ActiveReadingSession) {
        // Delete the existing active session
        let endedId = existingSession.id
        modelContext.delete(existingSession)
        try? modelContext.save()

        // Notify Watch
        WatchConnectivityManager.shared.sendActiveSessionEndToWatch(activeSessionId: endedId)

        // End any Live Activity
        Task {
            await ReadingSessionActivityManager.shared.endActivity()
        }

        // Clear pending
        pendingActiveSession = nil

        // Start the new session
        actuallyStartTimer()
    }

    private func syncWithLiveActivity() {
        // Sync the endPage from Live Activity if timer is active
        if timerStartTime != nil, let currentPage = ReadingSessionActivityManager.shared.getCurrentPage() {
            endPage = currentPage
            // Synced with Live Activity - this is expected behavior during active sessions
        }
    }

    private func startTimer() {
        // Check for existing active session
        if let activeSession = activeSessions.first {
            pendingActiveSession = activeSession
            showActiveSessionAlert = true
            return
        }

        // No active session - proceed with starting
        actuallyStartTimer()
    }

    private func actuallyStartTimer() {
        timerStartTime = Date()

        // Create active session
        let activeSession = ActiveReadingSession(
            book: book,
            startDate: Date(),
            currentPage: endPage,
            startPage: startPage,
            sourceDevice: "iPhone"
        )
        modelContext.insert(activeSession)
        try? modelContext.save()

        // Sync to Watch
        WatchConnectivityManager.shared.sendActiveSessionToWatch(activeSession)
        WidgetDataExporter.exportSnapshot(modelContext: modelContext)

        // Start Live Activity with current page
        Task {
            await ReadingSessionActivityManager.shared.startActivity(book: book, currentPage: endPage)
        }
    }

    private func pauseTimer() {
        guard let startTime = timerStartTime else { return }
        pausedElapsedTime += Date().timeIntervalSince(startTime)
        isPaused = true

        // Pause Live Activity
        Task {
            await ReadingSessionActivityManager.shared.pauseActivity()
        }
    }

    private func resumeTimer() {
        timerStartTime = Date()
        isPaused = false

        // Resume Live Activity
        Task {
            await ReadingSessionActivityManager.shared.resumeActivity()
        }
    }

    private func finishSession() {
        guard let startTime = timerStartTime else { return }
        let totalElapsed = isPaused ? pausedElapsedTime : pausedElapsedTime + Date().timeIntervalSince(startTime)
        durationMinutes = max(1, Int(totalElapsed / 60))
        timerStartTime = nil
        isPaused = false
        pausedElapsedTime = 0

        // End Live Activity and save
        saveSession()
    }

    private func finishActiveSession(_ activeSession: ActiveReadingSession) {
        let session = ReadingSession(
            startDate: activeSession.startDate,
            endDate: Date(),
            startPage: activeSession.startPage,
            endPage: activeSession.currentPage,
            durationMinutes: activeSession.durationMinutes,
            book: book
        )

        let engine = GamificationEngine(modelContext: modelContext)
        let xp = engine.calculateXP(for: session)
        session.xpEarned = xp

        modelContext.insert(session)
        if book.readingSessions == nil {
            book.readingSessions = []
        }
        book.readingSessions?.append(session)

        // Save position if requested
        if shouldSavePosition {
            let position = BookPosition(
                book: book,
                pageNumber: positionPage,
                lineNumber: Int(positionLineText),
                note: positionNote.isEmpty ? nil : positionNote
            )
            modelContext.insert(position)
        }

        // Clamp to max pages
        let maxPages = book.totalPages ?? Int.max
        book.currentPage = min(maxPages, activeSession.currentPage)

        if book.readingStatus == .wantToRead {
            book.readingStatus = .currentlyReading
            book.dateStarted = activeSession.startDate
        }

        if let profile = profiles.first {
            engine.awardXP(xp, to: profile)
            engine.updateStreak(for: profile, sessionDate: activeSession.startDate)
            engine.checkAchievements(for: profile)

            // ✅ ATOMIC: Send consolidated session completion (replaces 3 separate messages)
            // This guarantees the Watch receives: activeSessionEnd + session + liveActivityEnd
            // in a single atomic transfer with guaranteed delivery and correct ordering
            WatchConnectivityManager.shared.sendSessionCompletionToWatch(
                activeSessionId: activeSession.id,
                completedSession: session
            )

            Task {
                await ReadingSessionActivityManager.shared.endActivity()
                await WatchConnectivityManager.shared.syncBooksToWatch()
                WatchConnectivityManager.shared.sendProfileStatsToWatch(profile)
            }
        } else {
            // No profile - still need to end session on Watch
            WatchConnectivityManager.shared.sendSessionCompletionToWatch(
                activeSessionId: activeSession.id,
                completedSession: session
            )
            Task {
                await ReadingSessionActivityManager.shared.endActivity()
            }
        }

        // Delete active session locally
        modelContext.delete(activeSession)

        WidgetDataExporter.exportSnapshot(modelContext: modelContext)

        try? modelContext.save()
        dismiss()
    }

    private func saveSession() {
        // Delete any active session for this book
        if let activeSession = activeSessions.first {
            let endedId = activeSession.id
            modelContext.delete(activeSession)
            WatchConnectivityManager.shared.sendActiveSessionEndToWatch(activeSessionId: endedId)
        }

        let session = ReadingSession(
            startDate: sessionDate,
            endDate: sessionDate.addingTimeInterval(TimeInterval(durationMinutes * 60)),
            startPage: startPage,
            endPage: endPage,
            durationMinutes: durationMinutes,
            book: book
        )

        let engine = GamificationEngine(modelContext: modelContext)
        let xp = engine.calculateXP(for: session)
        session.xpEarned = xp

        modelContext.insert(session)
        if book.readingSessions == nil {
            book.readingSessions = []
        }
        book.readingSessions?.append(session)

        // Save position if requested
        if shouldSavePosition {
            let position = BookPosition(
                book: book,
                pageNumber: positionPage,
                lineNumber: Int(positionLineText),
                note: positionNote.isEmpty ? nil : positionNote
            )
            modelContext.insert(position)
        }

        // Update page and send to Watch (clamp to max pages)
        let maxPages = book.totalPages ?? Int.max
        let clampedEndPage = min(maxPages, endPage)
        let pageDelta = clampedEndPage - book.currentPage
        book.currentPage = clampedEndPage
        WatchConnectivityManager.shared.sendPageDeltaToWatch(bookUUID: book.id, delta: pageDelta)

        if book.readingStatus == .wantToRead {
        book.readingStatus = .currentlyReading
        book.dateStarted = sessionDate
    }

    if let profile = profiles.first {
        engine.awardXP(xp, to: profile)
        engine.updateStreak(for: profile, sessionDate: sessionDate)
        engine.checkAchievements(for: profile)

        // End Live Activity if still active
        Task {
            await ReadingSessionActivityManager.shared.endActivity()
            // Push the new session to Watch immediately for responsiveness
            WatchConnectivityManager.shared.sendSessionToWatch(session)
            // Sync new session to Watch
            await WatchConnectivityManager.shared.syncBooksToWatch()
            // Sync profile stats to Watch
            WatchConnectivityManager.shared.sendProfileStatsToWatch(profile)
        }
    }

    WidgetDataExporter.exportSnapshot(modelContext: modelContext)

    try? modelContext.save()
    dismiss()
}
}

struct ActiveSessionTimerView: View {
    @Environment(\.themeColor) private var themeColor
    @Bindable var activeSession: ActiveReadingSession

    private func formattedTime(at date: Date) -> String {
        let elapsed = activeSession.elapsedTime(at: date)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(formattedTime(at: context.date))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(activeSession.isPaused ? .orange : themeColor.color)
        }
    }
}

struct TimerView: View {
    @Environment(\.themeColor) private var themeColor
    let startTime: Date
    let isPaused: Bool
    let pausedElapsedTime: TimeInterval

    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var elapsedTime: TimeInterval {
        if isPaused {
            return pausedElapsedTime
        } else {
            return pausedElapsedTime + currentTime.timeIntervalSince(startTime)
        }
    }

    private var formattedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var body: some View {
        Text(formattedTime)
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(isPaused ? .orange : themeColor.color)
            .onReceive(timer) { _ in
                if !isPaused {
                    currentTime = Date()
                }
            }
    }
}

#Preview {
    LogReadingSessionView(book: Book(
        title: "Test Book",
        author: "Test Author",
        currentPage: 50
    ))
    .modelContainer(for: [Book.self, ReadingSession.self, UserProfile.self], inMemory: true)
}
