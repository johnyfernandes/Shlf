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
    @State private var useTimer = false
    @State private var timerStartTime: Date?

    init(book: Book) {
        self.book = book
        _startPage = State(initialValue: book.currentPage)
        _endPage = State(initialValue: book.currentPage)
    }

    private var pagesRead: Int {
        max(0, endPage - startPage)
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
                                Text("Reading...")
                                    .font(Theme.Typography.headline)

                                TimerView(startTime: startTime)

                                Button("Stop Timer") {
                                    stopTimer()
                                }
                                .primaryButton()
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
            .navigationTitle("Log Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSession()
                    }
                    .disabled(pagesRead <= 0 || (useTimer && timerStartTime != nil))
                }
            }
        }
    }

    private func startTimer() {
        timerStartTime = Date()
    }

    private func stopTimer() {
        guard let startTime = timerStartTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        durationMinutes = max(1, Int(elapsed / 60))
        timerStartTime = nil
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
        book.readingSessions.append(session)
        book.currentPage = endPage

        if book.readingStatus == .wantToRead {
            book.readingStatus = .currentlyReading
            book.dateStarted = sessionDate
        }

        if let profile = profiles.first {
            engine.awardXP(xp, to: profile)
            engine.updateStreak(for: profile, sessionDate: sessionDate)
            engine.checkAchievements(for: profile)
        }

        dismiss()
    }
}

struct TimerView: View {
    let startTime: Date

    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var elapsedTime: TimeInterval {
        currentTime.timeIntervalSince(startTime)
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
            .foregroundStyle(Theme.Colors.primary)
            .onReceive(timer) { _ in
                currentTime = Date()
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
