//
//  LogSessionWatchView.swift
//  ShlfWatch Watch App
//
//  Created by João Fernandes on 28/11/2025.
//

import SwiftUI
import SwiftData
import OSLog
import Combine

private enum ReadingConstants {
    static let estimatedMinutesPerPage = 2
    static let xpPerPage = 3
    static let defaultMaxPages = 1000
}

struct LogSessionWatchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Bindable var book: Book
    @Query private var profiles: [UserProfile]
    @Query private var activeSessions: [ActiveReadingSession]

    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }

        // CRITICAL: Check again after fetching to prevent race condition
        let descriptor = FetchDescriptor<UserProfile>()
        if let existingAfterFetch = try? modelContext.fetch(descriptor).first {
            return existingAfterFetch
        }

        // Now safe to create
        let new = UserProfile()
        modelContext.insert(new)
        try? modelContext.save() // Save immediately to prevent other threads from creating
        WatchConnectivityManager.logger.info("Created new UserProfile on Watch")
        return new
    }

    // Session state
    @State private var isActive = false
    @State private var isPaused = false
    @State private var startDate: Date?
    @State private var startPage: Int
    @State private var currentPage: Int
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showActiveSessionAlert = false
    @State private var pendingActiveSession: ActiveReadingSession?
    @State private var debounceTask: Task<Void, Never>?
    @State private var showBackButtonAlert = false
    @State private var showPositionMarked = false
    @State private var showMarkPageSheet = false
    @State private var markPageLine: Int = 1

    init(book: Book) {
        self.book = book
        _startPage = State(initialValue: book.currentPage)
        _currentPage = State(initialValue: book.currentPage)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Timer Display
                VStack(spacing: 4) {
                    Text(timeString)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(isPaused ? Color.orange : themeColor.color)
                        .monospacedDigit()

                    Text(isActive ? (isPaused ? "Paused" : "Reading...") : "Ready")
                        .font(.caption)
                        .foregroundStyle(isPaused ? Color.orange : Color.secondary)
                }
                .padding(.vertical)

                // Current Progress
                VStack(spacing: 8) {
                    HStack {
                        VStack {
                            Text("\(startPage)")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Start")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        Image(systemName: "arrow.right")
                            .foregroundStyle(themeColor.color)

                        VStack {
                            Text("\(currentPage)")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Current")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(8)

                    // Page controls (only when active)
                    if isActive {
                        HStack(spacing: 8) {
                            Button {
                                adjustPage(-1)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(currentPage <= startPage ? Color.secondary : themeColor.color)
                            }
                            .buttonStyle(.borderless)
                            .disabled(currentPage <= startPage)

                            Button {
                                adjustPage(1)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(currentPage >= (book.totalPages ?? ReadingConstants.defaultMaxPages) ? Color.secondary : themeColor.color)
                            }
                            .buttonStyle(.borderless)
                            .disabled(currentPage >= (book.totalPages ?? ReadingConstants.defaultMaxPages))
                        }
                        .font(.title2)
                    }
                }

                // Stats Preview
                if pagesRead > 0 {
                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text("\(pagesRead)")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("pages")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 2) {
                            Text("\(xpEarned)")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("XP")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 8)
                }

                // Control Buttons
                VStack(spacing: 8) {
                    if !isActive {
                        // Start Button
                        Button {
                            startSession()
                        } label: {
                            Label("Start Reading", systemImage: "play.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(themeColor.color)
                    } else {
                        // Pause/Resume Button
                        Button {
                            if isPaused {
                                resumeSession()
                            } else {
                                pauseSession()
                            }
                        } label: {
                            Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.circle.fill" : "pause.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        // Stop & Save Button
                        Button {
                            stopSession()
                        } label: {
                            Label("Finish Session", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(pagesRead == 0)

                        // Mark Position Button (if enabled in settings)
                        if profile.enableWatchPositionMarking {
                            Button {
                                markPageLine = 1
                                showMarkPageSheet = true
                            } label: {
                                Label(
                                    showPositionMarked ? "Position Saved!" : "Mark Position",
                                    systemImage: showPositionMarked ? "checkmark.circle.fill" : "bookmark.fill"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(showPositionMarked ? .green : themeColor.color)
                            .disabled(showPositionMarked)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Reading Session")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isActive)
        .toolbar {
            if isActive {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showBackButtonAlert = true
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .alert("Leave Active Session?", isPresented: $showBackButtonAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Leave Session", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("Your session is still active. Leaving won't end it, but you won't be able to track pages until you return.")
        }
        .sheet(isPresented: $showMarkPageSheet) {
            MarkPositionSheet(
                page: currentPage,
                lineNumber: $markPageLine,
                onSave: {
                    markPosition(lineNumber: markPageLine)
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PageDeltaFromPhone"))) { notification in
            // Sync currentPage with iPhone updates during active session
            if isActive,
               let userInfo = notification.userInfo,
               let bookUUID = userInfo["bookUUID"] as? UUID,
               let newPage = userInfo["newPage"] as? Int,
               bookUUID == book.id {
                currentPage = newPage
                WatchConnectivityManager.logger.info("🔄 Synced page from iPhone: \(newPage)")
            }
        }
        .onChange(of: activeSessions.first?.currentPage) { oldValue, newValue in
            // SINGLE SOURCE OF TRUTH: Always sync local state from model
            if let newPage = newValue, newPage != currentPage {
                currentPage = newPage
                WatchConnectivityManager.logger.info("✅ Synced page from active session: \(newPage)")
            }
            // If the active session disappears (ended on iPhone), clear local state
            if newValue == nil {
                resetActiveSessionState()
                WatchConnectivityManager.logger.info("🛑 Cleared active session state after end signal")
                dismiss()
            }
        }
        .onChange(of: book.currentPage) { _, newValue in
            // Keep ready-state pages aligned to the book when no active session
            guard !isActive else { return }
            startPage = newValue
            currentPage = newValue
        }
        .onAppear {
            loadExistingActiveSession()
        }
        .onDisappear {
            timer?.invalidate()
            debounceTask?.cancel()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            // Keep elapsed time synced from the model to avoid drift
            guard isActive else { return }
            if let activeSession = activeSessions.first {
                elapsedTime = activeSession.elapsedTime(at: date)
            } else if !isPaused {
                elapsedTime += 1
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
    }

    // MARK: - Computed Properties

    private var pagesRead: Int {
        max(0, currentPage - startPage)
    }

    private var xpEarned: Int {
        estimatedXP(
            pagesRead: pagesRead,
            durationMinutes: max(1, Int(currentElapsedSeconds / 60))
        )
    }

    private var timeString: String {
        let minutes = Int(currentElapsedSeconds) / 60
        let seconds = Int(currentElapsedSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var currentElapsedSeconds: TimeInterval {
        if let activeSession = activeSessions.first {
            return activeSession.elapsedTime(at: Date())
        }
        return elapsedTime
    }

    // MARK: - Session Control

    private func loadExistingActiveSession() {
        // Check if there's an existing active session and auto-load it
        guard let activeSession = activeSessions.first else { return }

        // Load the session state
        startPage = activeSession.startPage
        currentPage = activeSession.currentPage
        startDate = activeSession.startDate
        isPaused = activeSession.isPaused
        elapsedTime = activeSession.elapsedTime(at: Date())

        // Start timer if not paused
        isActive = true
        if !isPaused {
            timer = makeTickingTimer()
        }

        WatchConnectivityManager.logger.info("⌚️ Loaded active session from \(activeSession.sourceDevice): \(activeSession.pagesRead) pages")
    }

    private func endExistingSessionAndStartNew(_ existingSession: ActiveReadingSession) {
        // Delete the existing active session
        let endedId = existingSession.id
        modelContext.delete(existingSession)
        try? modelContext.save()

        // Notify iPhone
        WatchConnectivityManager.shared.sendActiveSessionEndToPhone(activeSessionId: endedId)

        // Clear pending
        pendingActiveSession = nil

        // Start the new session
        actuallyStartSession()
    }

    private func startSession() {
        // Check for existing active session
        if let activeSession = activeSessions.first {
            pendingActiveSession = activeSession
            showActiveSessionAlert = true
            return
        }

        // No active session - proceed with starting
        actuallyStartSession()
    }

    private func actuallyStartSession() {
        isActive = true
        isPaused = false
        startDate = Date()
        startPage = book.currentPage
        currentPage = book.currentPage
        elapsedTime = 0

        // Start timer
        timer = makeTickingTimer()

        // Create active session
        let activeSession = ActiveReadingSession(
            book: book,
            startDate: Date(),
            currentPage: currentPage,
            startPage: startPage,
            sourceDevice: "Watch"
        )
        modelContext.insert(activeSession)
        try? modelContext.save()

        // Sync to iPhone
        WatchConnectivityManager.shared.sendActiveSessionToPhone(activeSession)

        // ✅ CRITICAL: End any orphaned iPhone Live Activity first
        // This prevents dual active sessions and cleans up stale state
        WatchConnectivityManager.shared.sendLiveActivityEnd()

        // Start NEW Live Activity on iPhone
        WatchConnectivityManager.shared.sendLiveActivityStart(
            bookId: book.id,
            bookTitle: book.title,
            bookAuthor: book.author,
            totalPages: book.totalPages ?? 0,
            startPage: startPage,
            currentPage: currentPage,
            startTime: Date()
        )

        WatchConnectivityManager.logger.info("✅ Started session for \(book.title) (cleaned up any orphaned iPhone Live Activity)")
    }

    private func pauseSession() {
        isPaused = true

        // Update active session in database
        if let activeSession = activeSessions.first {
            activeSession.isPaused = true
            activeSession.pausedAt = Date()
            activeSession.lastUpdated = Date()
            try? modelContext.save()

            // Immediately update local elapsedTime to freeze the display
            elapsedTime = activeSession.elapsedTime(at: Date())

            // Send updated session to iPhone
            WatchConnectivityManager.shared.sendActiveSessionToPhone(activeSession)
        }

        // Sync pause to iPhone Live Activity
        WatchConnectivityManager.shared.sendLiveActivityPause()

        WatchConnectivityManager.logger.info("⏸️ Paused reading session and synced to iPhone")
    }

    private func resumeSession() {
        isPaused = false

        // Update active session in database
        if let activeSession = activeSessions.first {
            // Calculate paused duration and add to total
            if let pausedAt = activeSession.pausedAt {
                let pauseDuration = Date().timeIntervalSince(pausedAt)
                activeSession.totalPausedDuration += pauseDuration
            }
            activeSession.isPaused = false
            activeSession.pausedAt = nil
            activeSession.lastUpdated = Date()
            try? modelContext.save()

            // Force immediate update of local elapsedTime to resume counting
            elapsedTime = activeSession.elapsedTime(at: Date())

            // Send updated session to iPhone
            WatchConnectivityManager.shared.sendActiveSessionToPhone(activeSession)
        }

        // Sync resume to iPhone Live Activity
        WatchConnectivityManager.shared.sendLiveActivityResume()

        WatchConnectivityManager.logger.info("▶️ Resumed reading session and synced to iPhone")
    }

    private func stopSession() {
        guard let startDate = startDate else {
            WatchConnectivityManager.logger.error("No start date - session not started")
            timer?.invalidate()
            dismiss()
            return
        }

        guard pagesRead > 0 else {
            WatchConnectivityManager.logger.warning("No pages read - session not saved")
            timer?.invalidate()
            dismiss()
            return
        }

        // Capture active session ID before deleting
        let activeSessionId = activeSessions.first?.id

        // Delete any active session
        if let activeSession = activeSessions.first {
            modelContext.delete(activeSession)
        }

        // Stop timer
        timer?.invalidate()

        let endDate = Date()
        let durationMinutes = max(1, Int(currentElapsedSeconds / 60))

        // Create session
        let session = ReadingSession(
            startDate: startDate,
            endDate: endDate,
            startPage: startPage,
            endPage: currentPage,
            durationMinutes: durationMinutes,
            xpEarned: 0,
            isAutoGenerated: false,
            book: book
        )

        let engine = GamificationEngine(modelContext: modelContext)
        session.xpEarned = engine.calculateXP(for: session)

        modelContext.insert(session)
        WatchConnectivityManager.logger.info("Created session: book=\(session.book?.title ?? "nil"), pages=\(pagesRead), xp=\(session.xpEarned)")

        // Update book progress
        book.currentPage = currentPage

        // Update goals locally for Watch UI
        let currentProfile = profile
        let tracker = GoalTracker(modelContext: modelContext)
        tracker.updateGoals(for: currentProfile)

        // Save
        do {
            try modelContext.save()
            WatchConnectivityManager.logger.info("Saved session: \(pagesRead) pages, \(durationMinutes) min, \(session.xpEarned) XP")

            // ✅ ATOMIC: Send consolidated session completion (replaces 3 separate messages)
            // This guarantees the iPhone receives: activeSessionEnd + session + liveActivityEnd
            // in a single atomic transfer with guaranteed delivery and correct ordering
            if let activeId = activeSessionId {
                WatchConnectivityManager.shared.sendSessionCompletionToPhone(
                    activeSessionId: activeId,
                    completedSession: session
                )
            } else {
                // Fallback: if no active session existed, just send the completed session
                WatchConnectivityManager.shared.sendSessionToPhone(session)
                WatchConnectivityManager.shared.sendLiveActivityEnd()
            }

            dismiss()
        } catch {
            WatchConnectivityManager.logger.error("Failed to save session: \(error)")
        }
    }

    private func markPosition(lineNumber: Int) {
        let position = BookPosition(
            book: book,
            pageNumber: currentPage,
            lineNumber: lineNumber > 0 ? lineNumber : nil,
            timestamp: Date()
        )

        modelContext.insert(position)

        if book.bookPositions == nil {
            book.bookPositions = []
        }
        book.bookPositions?.append(position)

        do {
            try modelContext.save()
            let lineInfo = lineNumber > 0 ? ", Line \(lineNumber)" : ""
            WatchConnectivityManager.logger.info("Marked position: Page \(currentPage)\(lineInfo)")

            // Send position to iPhone
            Task.detached(priority: .userInitiated) {
                await WatchConnectivityManager.shared.sendBookPositionToPhone(position)
            }

            // Provide haptic feedback
            WKInterfaceDevice.current().play(.success)

            // Show visual confirmation
            withAnimation {
                showPositionMarked = true
            }

            // Hide confirmation after 2 seconds
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation {
                    showPositionMarked = false
                }
            }
        } catch {
            WatchConnectivityManager.logger.error("Failed to save position: \(error)")
        }
    }

    private func adjustPage(_ delta: Int) {
        debounceTask?.cancel()

        // Use active session if exists, otherwise local state
        if let activeSession = activeSessions.first {
            let newPage = activeSession.currentPage + delta
            if newPage >= activeSession.startPage && newPage <= (book.totalPages ?? ReadingConstants.defaultMaxPages) {
                activeSession.currentPage = newPage
                activeSession.lastUpdated = Date()
                currentPage = newPage
                scheduleDebouncedSync(for: activeSession)
            }
        } else {
            let newPage = currentPage + delta
            if newPage >= startPage && newPage <= (book.totalPages ?? ReadingConstants.defaultMaxPages) {
                currentPage = newPage

                scheduleDebouncedLiveActivityUpdate(
                    startPage: startPage,
                    endPage: currentPage,
                    durationMinutes: max(1, Int(elapsedTime / 60))
                )
            }
        }
    }

    private func scheduleDebouncedSync(for activeSession: ActiveReadingSession) {
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            try? modelContext.save()

            // Sync to iPhone (debounced to avoid spamming)
            WatchConnectivityManager.shared.sendActiveSessionToPhone(activeSession)

            // Update Live Activity
            let xpEarned = estimatedXP(
                pagesRead: activeSession.currentPage - activeSession.startPage,
                durationMinutes: max(1, Int(elapsedTime / 60))
            )
            WatchConnectivityManager.shared.sendLiveActivityUpdate(
                currentPage: activeSession.currentPage,
                xpEarned: xpEarned
            )
        }
    }

    private func scheduleDebouncedLiveActivityUpdate(startPage: Int, endPage: Int, durationMinutes: Int) {
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            let xpEarned = estimatedXP(
                pagesRead: endPage - startPage,
                durationMinutes: durationMinutes
            )
            WatchConnectivityManager.shared.sendLiveActivityUpdate(
                currentPage: endPage,
                xpEarned: xpEarned
            )
        }
    }

    /// Estimate XP for a reading session in progress
    /// Delegates to centralized XPCalculator for consistency
    private func estimatedXP(pagesRead: Int, durationMinutes: Int) -> Int {
        return XPCalculator.calculate(pagesRead: pagesRead, durationMinutes: durationMinutes)
    }

    private func resetActiveSessionState() {
        timer?.invalidate()
        isActive = false
        isPaused = false
        startDate = nil
        elapsedTime = 0
        startPage = book.currentPage
        currentPage = book.currentPage
    }

    private func makeTickingTimer() -> Timer {
        let newTimer = Timer(timeInterval: 1.0, repeats: true) { _ in
            if !isPaused {
                elapsedTime += 1
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        return newTimer
    }
}

#Preview {
    NavigationStack {
        LogSessionWatchView(book: Book(
            title: "Test Book",
            author: "Test Author",
            currentPage: 50,
            bookType: .physical,
            readingStatus: .currentlyReading
        ))
    }
}

// MARK: - Mark Position Sheet

struct MarkPositionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor

    let page: Int
    @Binding var lineNumber: Int
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Mark Position")
                .font(.footnote.weight(.semibold))

            // Page & Line in compact layout
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("Page")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(page)")
                        .font(.title3.bold())
                        .foregroundStyle(themeColor.color)
                }

                Divider()
                    .frame(height: 30)

                VStack(spacing: 2) {
                    Text("Line")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(lineNumber == 0 ? "—" : "\(lineNumber)")
                        .font(.title3.bold())
                        .foregroundStyle(themeColor.color)
                }
            }
            .padding(.vertical, 4)

            // Line number picker (Digital Crown)
            Picker("Line", selection: $lineNumber) {
                Text("—").tag(0)
                ForEach(1...50, id: \.self) { line in
                    Text("\(line)").tag(line)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 60)
            .labelsHidden()

            // Save button
            Button {
                onSave()
                dismiss()
            } label: {
                Text("Save")
                    .font(.footnote.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(themeColor.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
