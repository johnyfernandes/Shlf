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
    @Query private var profiles: [UserProfile]

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

    init(book: Book) {
        self.book = book
        _startPage = State(initialValue: book.currentPage)
        _endPage = State(initialValue: book.currentPage)
    }

    private var pagesRead: Int {
        max(0, endPage - startPage)
    }

    private var hasUnsavedData: Bool {
        // Has data if timer is running/paused, or pages have been logged
        return timerStartTime != nil || pagesRead > 0
    }

    private var estimatedXP: Int {
        let engine = GamificationEngine(modelContext: modelContext)
        let mockSession = ReadingSession(
            startPage: startPage,
            endPage: endPage,
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
                        TextField("Start", value: $startPage, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    HStack {
                        Text("To Page")
                        Spacer()
                        TextField("End", value: $endPage, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    HStack {
                        Image(systemName: "book.pages")
                            .foregroundStyle(Theme.Colors.primary)

                        Text("Pages Read")
                        Spacer()
                        Text("\(pagesRead)")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.primary)
                    }
                }

                Section("Duration") {
                    Toggle("Use Timer", isOn: $useTimer)

                    if useTimer {
                        if let startTime = timerStartTime {
                            VStack(spacing: Theme.Spacing.md) {
                                Text(isPaused ? "Paused" : "Reading...")
                                    .font(Theme.Typography.headline)
                                    .foregroundStyle(isPaused ? .orange : Theme.Colors.primary)

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
                                    .tint(Theme.Colors.primary)

                                    Button("Finish Session") {
                                        finishSession()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Theme.Colors.primary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.sm)
                        } else {
                            Button("Start Timer") {
                                startTimer()
                            }
                            .primaryButton()
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

    private func syncWithLiveActivity() {
        // Sync the endPage from Live Activity if timer is active
        if timerStartTime != nil, let currentPage = ReadingSessionActivityManager.shared.getCurrentPage() {
            endPage = currentPage
            print("🔄 Synced page from Live Activity: \(currentPage)")
        }
    }

    private func startTimer() {
        timerStartTime = Date()

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

    private func saveSession() {
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

        // Update page and send to Watch
        let pageDelta = endPage - book.currentPage
        book.currentPage = endPage
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

        dismiss()
    }
}

struct TimerView: View {
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
            .foregroundStyle(isPaused ? .orange : Theme.Colors.primary)
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
