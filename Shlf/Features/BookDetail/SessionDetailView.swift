//
//  SessionDetailView.swift
//  Shlf
//
//  Created by Codex on 03/02/2026.
//

import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
    @Environment(\.locale) private var locale

    let session: ReadingSession
    let book: Book

    @State private var showDeleteAlert = false

    private var pagesRead: Int {
        session.pagesRead
    }

    private var durationMinutes: Int {
        session.validDurationMinutes ?? session.durationMinutes
    }

    private var pacePerHour: Double? {
        guard durationMinutes > 0 else { return nil }
        return (Double(abs(pagesRead)) / Double(durationMinutes)) * 60
    }

    private var minutesPerPage: Double? {
        let pages = abs(pagesRead)
        guard durationMinutes > 0, pages > 0 else { return nil }
        return Double(durationMinutes) / Double(pages)
    }

    private var sessionImpactPercentage: Double? {
        guard let totalPages = book.totalPages, totalPages > 0 else { return nil }
        return (Double(abs(pagesRead)) / Double(totalPages)) * 100
    }

    private var startDateText: String {
        if durationMinutes > 0 {
            return session.startDate.formatted(date: .abbreviated, time: .shortened)
        }
        return session.startDate.formatted(date: .abbreviated, time: .omitted)
    }

    private var endDateText: String {
        if let endDate = session.endDate {
            if durationMinutes > 0 {
                return endDate.formatted(date: .abbreviated, time: .shortened)
            }
            return endDate.formatted(date: .abbreviated, time: .omitted)
        }
        return localized("SessionDetail.InProgress", locale: locale)
    }

    private var pagesReadText: String {
        pagesRead > 0 ? "+\(pagesRead)" : "\(pagesRead)"
    }

    private var durationText: String {
        String.localizedStringWithFormat(
            localized("BookDetail.Session.MinutesFormat %lld", locale: locale),
            durationMinutes
        )
    }

    private var xpText: String {
        "\(session.xpEarned)"
    }

    private var paceText: String {
        guard let pacePerHour else { return "—" }
        return String(format: "%.1f", pacePerHour)
    }

    private var timePerPageText: String {
        guard let minutesPerPage else { return "—" }
        return String(format: "%.1f", minutesPerPage)
    }

    private var sessionImpactText: String {
        guard let sessionImpactPercentage else { return "—" }
        return String(format: "%.1f%%", sessionImpactPercentage)
    }

    var body: some View {
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
                VStack(spacing: 20) {
                    heroCard
                    statsGrid
                    sessionRangeCard
                    timelineCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("SessionDetail.Title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("SessionDetail.Delete.Action", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(themeColor.color)
                }
            }
        }
        .alert("SessionDetail.Delete.Title", isPresented: $showDeleteAlert) {
            Button("Common.Delete", role: .destructive) {
                deleteSession()
            }
            Button("Common.Cancel", role: .cancel) {}
        } message: {
            Text("SessionDetail.Delete.Message")
        }
    }

    private var heroCard: some View {
        HStack(spacing: 16) {
            BookCoverView(
                imageURL: book.coverImageURL,
                title: book.title,
                width: 80,
                height: 120
            )
            .shadow(color: Theme.Shadow.medium, radius: 10, y: 6)

            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(2)

                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(session.startDate, style: .date)
                        .font(.caption)
                }
                .foregroundStyle(Theme.Colors.tertiaryText)

                if session.isImported || !session.countsTowardStats {
                    Text("SessionDetail.ImportedSession")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.15), in: Capsule())
                } else if session.isAutoGenerated {
                    Text("SessionDetail.AutoSession")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.15), in: Capsule())
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "SessionDetail.PagesRead",
                value: pagesReadText,
                icon: "book.pages",
                gradient: Theme.Colors.successGradient
            )

            StatCard(
                title: "SessionDetail.Duration",
                value: durationText,
                icon: "clock.fill",
                gradient: Theme.Colors.streakGradient
            )

            StatCard(
                title: "SessionDetail.XPEarned",
                value: xpText,
                icon: "bolt.fill",
                gradient: Theme.Colors.xpGradient
            )

            StatCard(
                title: "SessionDetail.PacePPH",
                value: paceText,
                icon: "speedometer",
                gradient: nil
            )

            StatCard(
                title: "SessionDetail.MinPerPage",
                value: timePerPageText,
                icon: "hourglass",
                gradient: nil
            )

            StatCard(
                title: "SessionDetail.Impact",
                value: sessionImpactText,
                icon: "percent",
                gradient: nil
            )
        }
    }

    private var sessionRangeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                    .font(.caption)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text("SessionDetail.Range.Title")
                    .font(.headline)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SessionDetail.Range.Start")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    Text(session.startPage, format: .number)
                        .font(.title3.weight(.semibold))
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .foregroundStyle(Theme.Colors.tertiaryText)

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("SessionDetail.Range.End")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    Text(session.endPage, format: .number)
                        .font(.title3.weight(.semibold))
                }
            }
            .padding(12)
            .background(themeColor.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text("SessionDetail.Timeline.Title")
                    .font(.headline)
            }

            VStack(spacing: 12) {
                HStack {
                    Text("SessionDetail.Timeline.Started")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    Spacer()
                    Text(startDateText)
                        .font(.subheadline.weight(.medium))
                }

                HStack {
                    Text("SessionDetail.Timeline.Ended")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    Spacer()
                    Text(endDateText)
                        .font(.subheadline.weight(.medium))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func deleteSession() {
        do {
            try SessionManager.deleteSession(session, in: modelContext)
            dismiss()
        } catch {
            #if DEBUG
            print("Failed to delete session: \(error.localizedDescription)")
            #else
            AppLogger.logError(error, context: "Delete session", logger: AppLogger.database)
            #endif
        }
    }
}

#Preview {
    let book = Book(title: "Sample Book", author: "Sample Author", totalPages: 240, currentPage: 120)
    let session = ReadingSession(
        startDate: Date().addingTimeInterval(-3600),
        endDate: Date(),
        startPage: 80,
        endPage: 120,
        durationMinutes: 45,
        xpEarned: 120,
        isAutoGenerated: false,
        book: book
    )

    return SessionDetailView(session: session, book: book)
        .modelContainer(for: [Book.self, ReadingSession.self], inMemory: true)
}
