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
    @State private var endPageText = ""
    @State private var durationMinutes = 30
    @State private var sessionDate = Date()
    @State private var useTimer = true
    @State private var timerStartTime: Date?
    @State private var isPaused = false
    @State private var pausedElapsedTime: TimeInterval = 0
    @State private var showDiscardAlert = false
    @State private var showActiveSessionAlert = false
    @State private var pendingActiveSession: ActiveReadingSession?
    @State private var activeSessionSnapshot = false
    @State private var xpGradientPhase: CGFloat = -0.6
    @FocusState private var focusedField: FocusField?

    enum FocusField: Hashable {
        case endPage
    }

    // Position tracking
    @State private var shouldSavePosition = false
    @State private var positionPage: Int
    @State private var positionLineText = ""
    @State private var positionNote = ""

    // Quote management
    @State private var showAddQuote = false
    @AppStorage("logSessionToPageTooltipDismissed") private var hasDismissedToPageTooltip = false
    @State private var showToPageTooltip = false

    init(book: Book) {
        self.book = book
        _startPage = State(initialValue: book.currentPage)
        _endPage = State(initialValue: book.currentPage)
        _positionPage = State(initialValue: book.currentPage)
        _endPageText = State(initialValue: "\(book.currentPage)")
    }

    // SINGLE SOURCE OF TRUTH - only bind to active session for this book
    private var activeSessionForBook: ActiveReadingSession? {
        activeSessions.first { $0.book?.id == book.id }
    }

    // Any active session (global), used to prevent parallel sessions
    private var anyActiveSession: ActiveReadingSession? {
        activeSessions.first
    }

    private var actualStartPage: Int {
        activeSessionForBook?.startPage ?? startPage
    }

    private var actualEndPage: Int {
        activeSessionForBook?.currentPage ?? endPage
    }

    private var isTimerActive: Bool {
        activeSessionForBook != nil || timerStartTime != nil
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
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [
                        themeColor.color.opacity(0.12),
                        themeColor.color.opacity(0.04),
                        Theme.Colors.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        progressCard
                        durationCard
                        positionCard
                        quoteCard
                        sessionDetailsCard
                        xpCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    if showToPageTooltip {
                        dismissToPageTooltip()
                    }
                })
                .scrollDismissesKeyboard(.interactively)
            }
            .onAppear {
                syncWithLiveActivity()
                syncEndPageText(with: actualEndPage)
                refreshActiveSessionSnapshot()
                if !hasDismissedToPageTooltip {
                    showToPageTooltip = true
                }
                if xpGradientPhase < 0 {
                    withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: true)) {
                        xpGradientPhase = 1.2
                    }
                }
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
            .onChange(of: actualEndPage) { _, newValue in
                syncEndPageText(with: newValue)
            }
            .onChange(of: focusedField) { _, newValue in
                if newValue == nil {
                    syncEndPageText(with: actualEndPage)
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
                    Button(hasUnsavedData ? "Minimize" : "Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSession()
                    }
                    .disabled(pagesRead <= 0 || (useTimer && timerStartTime != nil && !isPaused))
                }

                if hasUnsavedData {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Discard Session", role: .destructive) {
                                showDiscardAlert = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(themeColor.color)
                        }
                    }
                }
            }
            .alert("Discard Session?", isPresented: $showDiscardAlert) {
                Button("Keep Editing", role: .cancel) {}
                Button("Discard", role: .destructive) {
                    discardSession()
                }
            } message: {
                Text("This will end the timer and discard your session progress.")
            }
            .onChange(of: activeSessionForBook?.id) { _, newValue in
                if newValue != nil {
                    activeSessionSnapshot = true
                }
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

    private var progressCard: some View {
        sessionCard {
            cardHeader(title: "Reading Progress", icon: "book.pages")

            HStack(spacing: 12) {
                progressValueChip(title: "From", value: "\(actualStartPage)")
                progressInputChip(title: "To", text: $endPageText, showTooltip: showToPageTooltip)
            }

            HStack {
                Image(systemName: "book.pages")
                    .foregroundStyle(themeColor.color)

                Text("Pages Read")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(pagesRead)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(themeColor.color)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(themeColor.color.opacity(0.08), in: Capsule())
        }
    }

    private var durationCard: some View {
        sessionCard {
            cardHeader(title: "Duration", icon: "timer")

            VStack(spacing: 12) {
                if activeSessionForBook == nil {
                    Toggle("Use Timer", isOn: $useTimer)
                        .tint(themeColor.color)
                }

                if let session = activeSessionForBook {
                    VStack(spacing: 12) {
                        statusPill(text: session.isPaused ? "Paused" : "Reading...", isPaused: session.isPaused)

                        Text("Started on \(session.sourceDevice)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ActiveSessionTimerView(activeSession: session)

                        HStack(spacing: 10) {
                            Button(session.isPaused ? "Resume" : "Pause") {
                                Haptics.selection()
                                session.isPaused.toggle()
                                if session.isPaused {
                                    session.pausedAt = Date()
                                } else {
                                    if let pausedAt = session.pausedAt {
                                        session.totalPausedDuration += max(0, Date().timeIntervalSince(pausedAt))
                                    }
                                    session.pausedAt = nil
                                }
                                session.lastUpdated = Date()
                                try? modelContext.save()
                                WatchConnectivityManager.shared.sendActiveSessionToWatch(session)
                                WidgetDataExporter.exportSnapshot(modelContext: modelContext)
                                syncLiveActivity(with: session)
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
                } else if useTimer {
                    if let startTime = timerStartTime {
                        VStack(spacing: 12) {
                            statusPill(text: isPaused ? "Paused" : "Reading...", isPaused: isPaused)

                            TimerView(startTime: startTime, isPaused: isPaused, pausedElapsedTime: pausedElapsedTime)

                            HStack(spacing: 10) {
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
                    } else {
                        Button("Start Timer") {
                            startTimer()
                        }
                        .primaryButton(color: themeColor.color)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    DurationPickerView(minutes: $durationMinutes)
                }
            }
        }
    }

    private var positionCard: some View {
        sessionCard {
            HStack(spacing: 8) {
                Image(systemName: "bookmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text("Reading Position")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.text)

                Text("Optional")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.Colors.secondaryText)

                Spacer()
            }

            VStack(spacing: 12) {
                Toggle("Save reading position", isOn: $shouldSavePosition)
                    .tint(themeColor.color)
                    .onChange(of: shouldSavePosition) { _, newValue in
                        if newValue {
                            positionPage = endPage
                        }
                    }
                    .onChange(of: endPage) { _, newValue in
                        if shouldSavePosition {
                            positionPage = newValue
                        }
                    }

                if shouldSavePosition {
                    HStack {
                        Text("Page")
                        Spacer()
                        TextField("Page", value: $positionPage, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 80, alignment: .trailing)
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Line")
                        Spacer()
                        TextField("Line (optional)", text: $positionLineText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 80, alignment: .trailing)
                    }

                    TextField("Note (optional)", text: $positionNote, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
        }
    }

    private var quoteCard: some View {
        sessionCard {
            cardHeader(title: "Save Quote", icon: "quote.bubble")

            Button {
                showAddQuote = true
            } label: {
                Label("Add Quote from this Session", systemImage: "quote.bubble")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(themeColor.color)
        }
    }

    private var sessionDetailsCard: some View {
        sessionCard {
            cardHeader(title: "Session Details", icon: "calendar")

            DatePicker("Session Date", selection: $sessionDate, displayedComponents: [.date, .hourAndMinute])
                .tint(themeColor.color)
        }
    }

    private var xpCard: some View {
        sessionCard {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(xpGradient)

                Text("Estimated XP")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(xpGradient)

                Spacer()

                Text("+\(estimatedXP)")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(xpGradient)
                    .monospacedDigit()
            }
        }
    }

    private func cardHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(themeColor.color)
                .frame(width: 16)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.text)

            Spacer()
        }
    }

    private func progressValueChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.Colors.secondaryText)

            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.Colors.text)
                .monospacedDigit()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.tertiaryBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(themeColor.color.opacity(0.08), lineWidth: 1)
        )
    }

    private func progressInputChip(title: String, text: Binding<String>, showTooltip: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.Colors.secondaryText)

            HStack(spacing: 6) {
                TextField("End", text: text)
                    .keyboardType(.numberPad)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .focused($focusedField, equals: .endPage)
                    .onChange(of: text.wrappedValue) { _, newValue in
                        handleEndPageInput(newValue)
                    }
                    .monospacedDigit()

                Image(systemName: "pencil.line")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(focusedField == .endPage ? themeColor.color : Theme.Colors.tertiaryText)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.tertiaryBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(themeColor.color.opacity(0.08), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if showTooltip {
                endPageTooltip
                    .offset(x: 6, y: -58)
                    .allowsHitTesting(false)
            }
        }
    }

    private var xpGradient: LinearGradient {
        LinearGradient(
            colors: [
                themeColor.color.opacity(0.7),
                themeColor.color,
                themeColor.color.opacity(0.9)
            ],
            startPoint: UnitPoint(x: xpGradientPhase, y: 0),
            endPoint: UnitPoint(x: xpGradientPhase + 1.0, y: 1.0)
        )
    }

    private func sessionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(themeColor.color.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Theme.Shadow.small, radius: 3, y: 1)
    }

    private func statusPill(text: String, isPaused: Bool) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isPaused ? Color.orange : themeColor.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill((isPaused ? Color.orange : themeColor.color).opacity(0.12))
            )
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var endPageTooltip: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tap here!")
                .font(.caption.weight(.bold))
            Text("Tap here to edit your last page for this session.")
                .font(.caption2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(themeColor.color.gradient)
                .shadow(color: themeColor.color.opacity(0.35), radius: 6, y: 4)
        )
        .overlay(alignment: .bottomTrailing) {
            Rectangle()
                .fill(themeColor.color)
                .frame(width: 10, height: 10)
                .rotationEffect(.degrees(45))
                .offset(x: -18, y: 6)
        }
        .frame(maxWidth: 220, alignment: .leading)
    }

    private func dismissToPageTooltip() {
        showToPageTooltip = false
        hasDismissedToPageTooltip = true
    }

    private func discardSession() {
        if let activeSession = activeSessionForBook {
            let endedId = activeSession.id
            modelContext.delete(activeSession)
            try? modelContext.save()
            WatchConnectivityManager.shared.sendActiveSessionEndToWatch(activeSessionId: endedId)
            Task {
                await ReadingSessionActivityManager.shared.endActivity()
            }
        } else if timerStartTime != nil {
            Task {
                await ReadingSessionActivityManager.shared.endActivity()
            }
        }

        dismiss()
    }

    private func refreshActiveSessionSnapshot() {
        let bookId = book.id
        let descriptor = FetchDescriptor<ActiveReadingSession>(
            predicate: #Predicate<ActiveReadingSession> { session in
                session.book?.id == bookId
            }
        )
        if let sessions = try? modelContext.fetch(descriptor), !sessions.isEmpty {
            activeSessionSnapshot = true
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
        if let session = activeSessionForBook {
            endPage = session.currentPage
            syncLiveActivity(with: session)
            return
        }

        // Sync the endPage from Live Activity if timer is active
        if timerStartTime != nil, let currentPage = ReadingSessionActivityManager.shared.getCurrentPage() {
            endPage = currentPage
            // Synced with Live Activity - this is expected behavior during active sessions
        }
    }

    private func syncLiveActivity(with session: ActiveReadingSession) {
        Task {
            await ReadingSessionActivityManager.shared.syncActivityState(
                startTime: session.startDate,
                startPage: session.startPage,
                currentPage: session.currentPage,
                totalPausedDuration: session.totalPausedDuration,
                pausedAt: session.pausedAt,
                isPaused: session.isPaused,
                xpEarned: estimatedXP
            )
        }
    }

    private func handleEndPageInput(_ input: String) {
        let filtered = input.filter { $0.isNumber }
        if filtered != input {
            endPageText = filtered
            return
        }

        guard !filtered.isEmpty else {
            return
        }

        guard let newValue = Int(filtered) else { return }
        let clampedValue = clampEndPage(newValue)

        if clampedValue != newValue {
            endPageText = "\(clampedValue)"
        }

        if let session = activeSessionForBook {
            session.currentPage = clampedValue
            session.lastUpdated = Date()
            endPage = clampedValue
            try? modelContext.save()
            WatchConnectivityManager.shared.sendActiveSessionToWatch(session)
            WidgetDataExporter.exportSnapshot(modelContext: modelContext)
            syncLiveActivity(with: session)
            WidgetDataExporter.exportSnapshot(modelContext: modelContext)
        } else {
            endPage = clampedValue
        }
    }

    private func clampEndPage(_ value: Int) -> Int {
        if let maxPages = book.totalPages {
            return min(value, maxPages)
        }
        return value
    }

    private func syncEndPageText(with value: Int) {
        guard focusedField != .endPage else { return }
        let textValue = "\(value)"
        if endPageText != textValue {
            endPageText = textValue
        }
    }

    private func startTimer() {
        // Check for existing active session
        if let existing = anyActiveSession {
            pendingActiveSession = existing
            showActiveSessionAlert = true
            return
        }

        // No active session - proceed with starting
        actuallyStartTimer()
    }

    private func actuallyStartTimer() {
        Haptics.impact(.light)
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
            let themeHex = profiles.first?.themeColor.color.toHex() ?? "#00CED1"
            await ReadingSessionActivityManager.shared.startActivity(book: book, currentPage: endPage, themeColorHex: themeHex)
        }
    }

    private func pauseTimer() {
        Haptics.selection()
        guard let startTime = timerStartTime else { return }
        pausedElapsedTime += Date().timeIntervalSince(startTime)
        isPaused = true

        // Pause Live Activity
        Task {
            await ReadingSessionActivityManager.shared.pauseActivity()
        }
    }

    private func resumeTimer() {
        Haptics.selection()
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
        Haptics.impact(.medium)
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
        // SwiftData manages relationships automatically

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
            // CRITICAL: Only award if not already awarded (prevent double-counting)
            if !session.xpAwarded {
                engine.awardXP(xp, to: profile)
                session.xpAwarded = true
            }
            engine.updateStreak(for: profile, sessionDate: activeSession.startDate)
            engine.checkAchievements(for: profile)
        }

        // Delete active session locally
        modelContext.delete(activeSession)

        WidgetDataExporter.exportSnapshot(modelContext: modelContext)

        // SAVE FIRST before any async operations
        try? modelContext.save()

        // Now send updates AFTER save
        if let profile = profiles.first {
            WatchConnectivityManager.shared.sendSessionCompletionToWatch(
                activeSessionId: activeSession.id,
                completedSession: session
            )
            WatchConnectivityManager.shared.sendProfileStatsToWatch(profile)

            Task {
                await ReadingSessionActivityManager.shared.endActivity()
            }
        } else {
            WatchConnectivityManager.shared.sendSessionCompletionToWatch(
                activeSessionId: activeSession.id,
                completedSession: session
            )
            Task {
                await ReadingSessionActivityManager.shared.endActivity()
            }
        }

        dismiss()
    }

    private func saveSession() {
        Haptics.impact(.medium)
        // Delete any active session for this book
        if let activeSession = activeSessionForBook {
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
        // SwiftData manages relationships automatically

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
        WatchConnectivityManager.shared.sendPageDeltaToWatch(
            bookUUID: book.id,
            delta: pageDelta,
            newPage: book.currentPage
        )

        if book.readingStatus == .wantToRead {
        book.readingStatus = .currentlyReading
        book.dateStarted = sessionDate
    }

    if let profile = profiles.first {
        // CRITICAL: Only award if not already awarded (prevent double-counting)
        if !session.xpAwarded {
            engine.awardXP(xp, to: profile)
            session.xpAwarded = true
        }
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
