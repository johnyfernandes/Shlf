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
    @Environment(\.themeColor) private var themeColor
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var book: Book
    @Query private var profiles: [UserProfile]

    @State private var showingAddPages = false

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

    var body: some View {
        TabView {
            progressPage
            actionsPage
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddPages) {
            AddPagesWatchView(book: book)
        }
    }

    private var progressPage: some View {
        VStack(spacing: 10) {
            if !book.author.isEmpty {
                Text(book.author)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            progressSummary

            ViewThatFits(in: .vertical) {
                VStack(spacing: 8) {
                    stepperRow

                    HStack(spacing: 6) {
                        quickAddButton(5)
                        quickAddButton(10)
                        quickAddButton(20)
                    }
                }

                VStack(spacing: 8) {
                    stepperRow
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var progressSummary: some View {
        Group {
            if let totalPages = book.totalPages {
                if profile.useCircularProgressWatch {
                    ZStack {
                        Circle()
                            .stroke(.tertiary.opacity(0.2), lineWidth: 6)
                            .frame(width: 86, height: 86)

                        Circle()
                            .trim(from: 0, to: book.progressPercentage / 100)
                            .stroke(themeColor.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 86, height: 86)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: book.currentPage)

                        VStack(spacing: 0) {
                            Text(book.currentPage, format: .number)
                                .font(.system(size: 32, weight: .bold, design: .rounded))

                            Text("/ \(totalPages, format: .number)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    VStack(spacing: 4) {
                        Text(book.currentPage, format: .number)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(themeColor.color)

                        Text(
                            String.localizedStringWithFormat(
                                String(localized: "Watch.Book.ProgressOfPages %lld"),
                                totalPages
                            )
                        )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ProgressView(value: Double(book.currentPage), total: Double(totalPages))
                            .tint(themeColor.color)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var stepperRow: some View {
        HStack(spacing: 12) {
            Button {
                addPages(-1)
            } label: {
                Image(systemName: "minus")
                    .font(.title3.weight(.semibold))
                    .frame(width: 40, height: 30)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(book.currentPage <= 0)

            Button {
                addPages(1)
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .frame(width: 40, height: 30)
                    .foregroundStyle(themeColor.onColor(for: colorScheme))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(themeColor.color)
        }
    }

    private var actionsPage: some View {
        ScrollView {
            VStack(spacing: 10) {
                VStack(spacing: 8) {
                    Button {
                        showingAddPages = true
                    } label: {
                        Label("Watch.Book.CustomAmount", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)

                    NavigationLink {
                        LogSessionWatchView(book: book)
                    } label: {
                        Label("Watch.Book.LogSession", systemImage: "clock.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    NavigationLink {
                        SessionsListWatchView(book: book)
                    } label: {
                        Label("Watch.Book.ViewSessions", systemImage: "list.bullet")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if let lastPos = book.lastPosition {
                    Divider()
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Watch.Book.LastPosition")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(lastPos.positionDescription)
                            .font(.footnote.weight(.medium))

                        if let note = lastPos.note {
                            Text(note)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Button {
                            book.currentPage = lastPos.pageNumber
                            // CRITICAL: Save so resume persists
                            try? modelContext.save()

                            // Send delta to iPhone
                            let delta = PageDelta(
                                bookUUID: book.id,
                                delta: 0,
                                newPage: book.currentPage
                            ) // No pages read, just position change
                            WatchConnectivityManager.shared.sendPageDelta(delta)
                        } label: {
                            Label("Watch.Book.ResumeHere", systemImage: "arrow.forward.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .tint(themeColor.color)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let quotes = book.quotes, !quotes.isEmpty {
                    Divider()
                        .padding(.vertical, 2)

                    NavigationLink {
                        QuotesListWatchView(quotes: quotes)
                    } label: {
                        Label {
                            Text(
                                String.localizedStringWithFormat(
                                    String(localized: "View Quotes (%lld)"),
                                    quotes.count
                                )
                            )
                        } icon: {
                            Image(systemName: "quote.bubble")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private func quickAddButton(_ amount: Int) -> some View {
        Button {
            addPages(amount)
        } label: {
            Text(verbatim: "+\(amount)")
                .font(.caption2.weight(.medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .tint(themeColor.color)
    }

    private func addPages(_ pages: Int) {
        let oldPage = book.currentPage
        let newPage = book.currentPage + pages

        // Clamp to valid range
        book.currentPage = max(0, min((book.totalPages ?? ReadingConstants.defaultMaxPages), newPage))

        let actualDelta = book.currentPage - oldPage
        if actualDelta == 0 { return }

        // Send delta to iPhone
        let delta = PageDelta(bookUUID: book.id, delta: actualDelta, newPage: book.currentPage)
        WatchConnectivityManager.shared.sendPageDelta(delta)

        // Create session only for positive progress
        let pagesRead = book.currentPage - oldPage
        if pagesRead > 0 {
            let currentProfile = profile
            let engine = GamificationEngine(modelContext: modelContext)
            let session = ReadingSession(
                endDate: Date(),
                startPage: oldPage,
                endPage: book.currentPage,
                durationMinutes: pagesRead * ReadingConstants.estimatedMinutesPerPage,
                xpEarned: 0,
                isAutoGenerated: true,
                book: book
            )
            session.xpEarned = engine.calculateXP(for: session)

            // CRITICAL: Mark as awarded so iPhone doesn't double-count
            session.xpAwarded = true

            modelContext.insert(session)

            // Update goals locally for Watch UI
            let tracker = GoalTracker(modelContext: modelContext)
            tracker.updateGoals(for: currentProfile)

            // Save changes
            do {
                try modelContext.save()

                // Sync in background to avoid blocking UI
                Task.detached(priority: .userInitiated) {
                    await WatchConnectivityManager.shared.sendSessionToPhone(session)
                    await WatchConnectivityManager.shared.sendProfileStatsToPhone(currentProfile)
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
    @Environment(\.themeColor) private var themeColor
    @Environment(\.colorScheme) private var colorScheme
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

        // CRITICAL: Check again after fetching to prevent race condition
        let descriptor = FetchDescriptor<UserProfile>()
        if let existingAfterFetch = try? modelContext.fetch(descriptor).first {
            return existingAfterFetch
        }

        // Now safe to create
        let new = UserProfile()
        modelContext.insert(new)
        try? modelContext.save() // Save immediately to prevent other threads from creating
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
            Text(verbatim: intAmount > 0 ? "+\(intAmount)" : "\(intAmount)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(intAmount > 0 ? themeColor.color : intAmount < 0 ? .orange : .secondary)
                .focusable()
                .digitalCrownRotation($amount, from: -50.0, through: 100.0, by: 1.0, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
                .focused($isFocused)
                .frame(height: 80)

            Text(intAmount == 0 ? String(localized: "Watch.Book.UseDigitalCrown") : intAmount > 0 ? String(localized: "Watch.Book.PagesToAdd") : String(localized: "Watch.Book.PagesToRemove"))
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
                        .foregroundStyle(intAmount > 0 ? themeColor.onColor(for: colorScheme) : .white)
                }
                .buttonStyle(.borderedProminent)
                .tint(intAmount > 0 ? themeColor.color : .orange)
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
        let delta = PageDelta(bookUUID: book.id, delta: actualDelta, newPage: book.currentPage)
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

            // CRITICAL: Mark as awarded so iPhone doesn't double-count
            session.xpAwarded = true

            modelContext.insert(session)

            let tracker = GoalTracker(modelContext: modelContext)
            tracker.updateGoals(for: currentProfile)

            do {
                try modelContext.save()
                Task.detached(priority: .userInitiated) {
                    await WatchConnectivityManager.shared.sendSessionToPhone(session)
                    await WatchConnectivityManager.shared.sendProfileStatsToPhone(currentProfile)
                }
            } catch {
                WatchConnectivityManager.logger.error("Failed to save: \(error)")
            }
        }

        dismiss()
    }
}
