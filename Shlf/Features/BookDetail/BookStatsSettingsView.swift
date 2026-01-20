//
//  BookStatsSettingsView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BookStatsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Bindable var profile: UserProfile

    @State private var editMode: EditMode = .inactive
    @State private var draggedCard: BookStatsCardType?
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    private var availableCards: [BookStatsCardType] {
        BookStatsCardType.allCases.filter { !profile.bookStatsCards.contains($0) }
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
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.caption)
                                .foregroundStyle(themeColor.color)
                                .frame(width: 16)

                            Text("About")
                                .font(.headline)
                        }

                        Text("Customize the stats shown on each book. Reorder, hide, or add cards anytime.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundStyle(themeColor.color)
                                .frame(width: 16)

                            Text("Default Range")
                                .font(.headline)
                        }

                        VStack(spacing: 10) {
                            ForEach(BookStatsRange.allCases) { range in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                        profile.bookStatsRange = range
                                        saveChanges()
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(range.titleKey)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        if profile.bookStatsRange == range {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(themeColor.color)
                                        }
                                    }
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(
                                                profile.bookStatsRange == range ? themeColor.color : .clear,
                                                lineWidth: 2
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.caption)
                                .foregroundStyle(themeColor.color)
                                .frame(width: 16)

                            Text("Data Sources")
                                .font(.headline)
                        }

                        Toggle("Include imported sessions", isOn: $profile.bookStatsIncludeImported)
                            .tint(themeColor.color)
                            .onChange(of: profile.bookStatsIncludeImported) { _, _ in
                                saveChanges()
                            }

                        Toggle("Include excluded sessions", isOn: $profile.bookStatsIncludeExcluded)
                            .tint(themeColor.color)
                            .onChange(of: profile.bookStatsIncludeExcluded) { _, _ in
                                saveChanges()
                            }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    if !profile.bookStatsCards.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundStyle(themeColor.color)
                                        .frame(width: 16)

                                    Text("Visible Stats")
                                        .font(.headline)
                                }

                                Spacer()

                                Text(
                                    String.localizedStringWithFormat(
                                        String(localized: "%lld/%lld"),
                                        profile.bookStatsCards.count,
                                        BookStatsCardType.allCases.count
                                    )
                                )
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(themeColor.color.opacity(0.1), in: Capsule())
                            }

                            VStack(spacing: 10) {
                                ForEach(profile.bookStatsCards) { cardType in
                                    BookStatsCardRow(
                                        card: cardType,
                                        isEditing: editMode == .active,
                                        onRemove: {
                                            withAnimation {
                                                profile.removeBookStatsCard(cardType)
                                                saveChanges()
                                            }
                                        }
                                    )
                                    .onDrag {
                                        self.draggedCard = cardType
                                        return NSItemProvider(object: cardType.rawValue as NSString)
                                    }
                                    .onDrop(of: [UTType.text], delegate: BookStatsDropDelegate(
                                        card: cardType,
                                        cards: $profile.bookStatsCardOrder,
                                        draggedCard: $draggedCard,
                                        modelContext: modelContext
                                    ))
                                }
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    if !availableCards.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(themeColor.color)
                                    .frame(width: 16)

                                Text("Available Stats")
                                    .font(.headline)
                            }

                            VStack(spacing: 10) {
                                ForEach(availableCards) { cardType in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                            profile.addBookStatsCard(cardType)
                                            saveChanges()
                                        }
                                    } label: {
                                        BookStatsCardRow(card: cardType, isEditing: false, onRemove: {})
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        InlineEmptyStateView(
                            icon: "checkmark.circle",
                            title: "All stats added",
                            message: "Use Edit to reorder your stats."
                        )
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Book Stats")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
        .toolbar {
            if !profile.bookStatsCards.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    } label: {
                        Text(editMode == .active ? "Done" : "Edit")
                            .fontWeight(.semibold)
                            .foregroundStyle(themeColor.color)
                    }
                }
            }
        }
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK") {}
        } message: {
            Text(saveErrorMessage)
        }
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            saveErrorMessage = "Failed to save setting: \(error.localizedDescription)"
            showSaveError = true
        }
    }
}

private struct BookStatsCardRow: View {
    @Environment(\.themeColor) private var themeColor
    let card: BookStatsCardType
    let isEditing: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: card.icon)
                .font(.title3)
                .foregroundStyle(card.accent.color(themeColor: themeColor))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(card.titleKey)
                    .font(.subheadline.weight(.medium))
                Text(card.descriptionKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if isEditing {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .red)
                        .symbolRenderingMode(.palette)
                }
                .offset(x: 8, y: -8)
            }
        }
    }
}

private struct BookStatsDropDelegate: DropDelegate {
    let card: BookStatsCardType
    @Binding var cards: [String]
    @Binding var draggedCard: BookStatsCardType?
    let modelContext: ModelContext

    func performDrop(info: DropInfo) -> Bool {
        true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedCard else { return }
        if draggedCard != card {
            guard let from = cards.firstIndex(of: draggedCard.rawValue),
                  let to = cards.firstIndex(of: card.rawValue) else {
                return
            }
            Haptics.selection()
            withAnimation(Theme.Animation.snappy) {
                cards.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                try? modelContext.save()
            }
        }
    }
}

#Preview {
    NavigationStack {
        BookStatsSettingsView(profile: UserProfile())
    }
    .modelContainer(for: [UserProfile.self, Book.self], inMemory: true)
}
