//
//  LogSessionWatchView.swift
//  ShlfWatch Watch App
//
//  Created by João Fernandes on 28/11/2025.
//

import SwiftUI
import SwiftData
import OSLog

private enum ReadingConstants {
    static let estimatedMinutesPerPage = 2
    static let xpPerPage = 3
    static let defaultMaxPages = 1000
}

struct LogSessionWatchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var book: Book
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }
        // Auto-create profile if it doesn't exist
        let new = UserProfile()
        modelContext.insert(new)
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
                        .foregroundStyle(.cyan)
                        .monospacedDigit()

                    Text(isActive ? (isPaused ? "Paused" : "Reading...") : "Ready")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                            .foregroundStyle(.cyan)

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
                    .background(.regularMaterial)
                    .cornerRadius(8)

                    // Page controls (only when active)
                    if isActive {
                        HStack(spacing: 8) {
                            Button {
                                adjustPage(-1)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(currentPage <= startPage ? Color.secondary : Color.cyan)
                            }
                            .buttonStyle(.borderless)
                            .disabled(currentPage <= startPage)

                            Button {
                                adjustPage(1)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(currentPage >= (book.totalPages ?? ReadingConstants.defaultMaxPages) ? Color.secondary : Color.cyan)
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
                        .tint(.cyan)
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
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Reading Session")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            timer?.invalidate()
        }
    }

    // MARK: - Computed Properties

    private var pagesRead: Int {
        max(0, currentPage - startPage)
    }

    private var xpEarned: Int {
        pagesRead * ReadingConstants.xpPerPage
    }

    private var timeString: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Session Control

    private func startSession() {
        isActive = true
        isPaused = false
        startDate = Date()
        startPage = book.currentPage
        currentPage = book.currentPage
        elapsedTime = 0

        // Start timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if !isPaused {
                elapsedTime += 1
            }
        }

        WatchConnectivityManager.logger.info("Started reading session for \(book.title)")
    }

    private func pauseSession() {
        isPaused = true
        WatchConnectivityManager.logger.info("Paused reading session")
    }

    private func resumeSession() {
        isPaused = false
        WatchConnectivityManager.logger.info("Resumed reading session")
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

        // Stop timer
        timer?.invalidate()

        let endDate = Date()
        let durationMinutes = max(1, Int(elapsedTime / 60))

        // Create session
        let session = ReadingSession(
            startDate: startDate,
            endDate: endDate,
            startPage: startPage,
            endPage: currentPage,
            durationMinutes: durationMinutes,
            xpEarned: xpEarned,
            isAutoGenerated: false,
            book: book
        )

        modelContext.insert(session)
        WatchConnectivityManager.logger.info("Created session: book=\(session.book?.title ?? "nil"), pages=\(pagesRead), xp=\(xpEarned)")

        // Update book progress
        book.currentPage = currentPage

        // Send page delta to iPhone
        let delta = PageDelta(bookUUID: book.id, delta: pagesRead)
        WatchConnectivityManager.shared.sendPageDelta(delta)

        // Award XP
        let currentProfile = profile
        currentProfile.totalXP += xpEarned
        WatchConnectivityManager.logger.info("Awarded \(xpEarned) XP to profile, new total: \(currentProfile.totalXP)")

        // Update goals
        let tracker = GoalTracker(modelContext: modelContext)
        tracker.updateGoals(for: currentProfile)

        // Save
        do {
            try modelContext.save()
            WatchConnectivityManager.logger.info("Saved session: \(pagesRead) pages, \(durationMinutes) min, \(xpEarned) XP")

            // Send session to iPhone immediately
            WatchConnectivityManager.shared.sendSessionToPhone(session)

            dismiss()
        } catch {
            WatchConnectivityManager.logger.error("Failed to save session: \(error)")
        }
    }

    private func adjustPage(_ delta: Int) {
        let newPage = currentPage + delta
        if newPage >= startPage && newPage <= (book.totalPages ?? ReadingConstants.defaultMaxPages) {
            currentPage = newPage
        }
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
