//
//  BookDetailWatchView.swift
//  ShlfWatch Watch App
//
//  Created by João Fernandes on 27/11/2025.
//

import SwiftUI
import SwiftData
import OSLog

private enum ReadingConstants {
    static let estimatedMinutesPerPage = 2
    static let xpPerPage = 10 // Match GamificationEngine: 10 XP per page
    static let defaultMaxPages = 1000
}

struct BookDetailWatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var book: Book
    @Query private var profiles: [UserProfile]

    @State private var showingAddPages = false

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

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Book info
                VStack(spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text(book.author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Progress
                if let totalPages = book.totalPages {
                    VStack(spacing: 8) {
                        Text("\(book.currentPage)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.cyan)

                        Text("of \(totalPages) pages")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ProgressView(value: Double(book.currentPage), total: Double(totalPages))
                            .tint(.cyan)
                    }
                    .padding(.vertical)
                }

                // Quick stepper (Apple-style)
                HStack(spacing: 12) {
                    Button {
                        addPages(-1)
                    } label: {
                        Image(systemName: "minus")
                            .font(.title2.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    .disabled(book.currentPage <= 0)

                    Button {
                        addPages(1)
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                }

                // Preset quick adds
                HStack(spacing: 6) {
                    quickAddButton(5)
                    quickAddButton(10)
                    quickAddButton(20)
                }

                // Custom amount with Digital Crown
                Button {
                    showingAddPages = true
                } label: {
                    Label("Custom Amount", systemImage: "slider.horizontal.3")
                        .font(.footnote)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                // Session actions
                Divider()
                    .padding(.vertical, 4)

                VStack(spacing: 8) {
                    NavigationLink {
                        LogSessionWatchView(book: book)
                    } label: {
                        Label("Log Session", systemImage: "clock.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    NavigationLink {
                        SessionsListWatchView(book: book)
                    } label: {
                        Label("View Sessions", systemImage: "list.bullet")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddPages) {
            AddPagesWatchView(book: book)
        }
    }

    @ViewBuilder
    private func quickAddButton(_ amount: Int) -> some View {
        Button {
            addPages(amount)
        } label: {
            Text("+\(amount)")
                .font(.caption2.weight(.medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.cyan)
    }

    private func addPages(_ pages: Int) {
        let oldPage = book.currentPage
        let newPage = book.currentPage + pages

        // Clamp to valid range
        book.currentPage = max(0, min((book.totalPages ?? ReadingConstants.defaultMaxPages), newPage))

        let actualDelta = book.currentPage - oldPage
        if actualDelta == 0 { return }

        // Send delta to iPhone
        let delta = PageDelta(bookUUID: book.id, delta: actualDelta)
        WatchConnectivityManager.shared.sendPageDelta(delta)

        // Create session only for positive progress
        let pagesRead = book.currentPage - oldPage
        if pagesRead > 0 {
            let currentProfile = profile
            let engine = GamificationEngine(modelContext: modelContext)
            let session = ReadingSession(
                startPage: oldPage,
                endPage: book.currentPage,
                durationMinutes: pagesRead * ReadingConstants.estimatedMinutesPerPage,
                xpEarned: 0,
                isAutoGenerated: true,
                book: book
            )
            session.xpEarned = engine.calculateXP(for: session)
            modelContext.insert(session)

            // Update goals locally for Watch UI
            let tracker = GoalTracker(modelContext: modelContext)
            tracker.updateGoals(for: currentProfile)

            // Save changes
            do {
                try modelContext.save()

                // Sync in background to avoid blocking UI
                Task.detached(priority: .userInitiated) {
                    WatchConnectivityManager.shared.sendSessionToPhone(session)
                    WatchConnectivityManager.shared.sendProfileStatsToPhone(currentProfile)
                }
            } catch {
                WatchConnectivityManager.logger.error("Failed to save reading session: \(error)")
            }
        }
    }
}

struct AddPagesWatchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var book: Book
    @Query private var profiles: [UserProfile]

    @State private var amount = 0.0
    @FocusState private var isFocused: Bool

    private var intAmount: Int {
        Int(amount.rounded())
    }

    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }
        let new = UserProfile()
        modelContext.insert(new)
        return new
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Adjust Pages")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            // Digital Crown scrollable value
            Text("\(intAmount > 0 ? "+" : "")\(intAmount)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(intAmount > 0 ? .cyan : intAmount < 0 ? .orange : .secondary)
                .focusable()
                .digitalCrownRotation($amount, from: -50.0, through: 100.0, by: 1.0, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
                .focused($isFocused)
                .frame(height: 80)

            Text(intAmount == 0 ? "Use Digital Crown" : intAmount > 0 ? "pages to add" : "pages to remove")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer()

            // Buttons always visible in same position
            HStack(spacing: 8) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button {
                    applyAndDismiss()
                } label: {
                    Text("Apply")
                }
                .buttonStyle(.borderedProminent)
                .tint(intAmount > 0 ? .cyan : .orange)
                .disabled(intAmount == 0)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .onAppear {
            isFocused = true
        }
    }

    private func applyAndDismiss() {
        let oldPage = book.currentPage
        let newPage = book.currentPage + intAmount

        // Clamp to valid range
        book.currentPage = max(0, min((book.totalPages ?? ReadingConstants.defaultMaxPages), newPage))

        let actualDelta = book.currentPage - oldPage

        if actualDelta == 0 {
            dismiss()
            return
        }

        // Send delta to iPhone
        let delta = PageDelta(bookUUID: book.id, delta: actualDelta)
        WatchConnectivityManager.shared.sendPageDelta(delta)

        // Create session only for positive progress
        if actualDelta > 0 {
            let currentProfile = profile
            let engine = GamificationEngine(modelContext: modelContext)
            let session = ReadingSession(
                startPage: oldPage,
                endPage: book.currentPage,
                durationMinutes: actualDelta * ReadingConstants.estimatedMinutesPerPage,
                xpEarned: 0,
                isAutoGenerated: true,
                book: book
            )
            session.xpEarned = engine.calculateXP(for: session)
            modelContext.insert(session)

            let tracker = GoalTracker(modelContext: modelContext)
            tracker.updateGoals(for: currentProfile)

            do {
                try modelContext.save()
                Task.detached(priority: .userInitiated) {
                    WatchConnectivityManager.shared.sendSessionToPhone(session)
                    WatchConnectivityManager.shared.sendProfileStatsToPhone(currentProfile)
                }
            } catch {
                WatchConnectivityManager.logger.error("Failed to save: \(error)")
            }
        }

        dismiss()
    }
}
