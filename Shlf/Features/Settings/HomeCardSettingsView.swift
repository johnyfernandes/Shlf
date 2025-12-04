//
//  HomeCardSettingsView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct HomeCardSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Bindable var profile: UserProfile
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    @State private var editMode: EditMode = .inactive
    @State private var draggedCard: StatCardType?

    private var engine: GamificationEngine {
        GamificationEngine(modelContext: modelContext)
    }

    private var availableCards: [StatCardType] {
        StatCardType.allCases.filter { !profile.homeCards.contains($0) }
    }

    private func getValue(for cardType: StatCardType) -> String {
        switch cardType {
        case .currentStreak:
            return "\(profile.currentStreak)"
        case .longestStreak:
            return "\(profile.longestStreak)"
        case .level:
            return "\(profile.currentLevel)"
        case .totalXP:
            return "\(profile.totalXP)"
        case .booksRead:
            return "\(engine.totalBooksRead())"
        case .pagesRead:
            return "\(engine.totalPagesRead())"
        case .thisYear:
            return "\(engine.booksReadThisYear())"
        case .thisMonth:
            return "\(engine.booksReadThisMonth())"
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Dynamic gradient background
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
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.grid.3x3.fill")
                                .font(.caption)
                                .foregroundStyle(themeColor.color)
                                .frame(width: 16)

                            Text("About")
                                .font(.headline)
                        }

                        Text("Customize which stats appear on your home page. You can show up to 3 cards.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Active Cards
                    if !profile.homeCards.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundStyle(themeColor.color)
                                        .frame(width: 16)

                                    Text("Active Cards")
                                        .font(.headline)
                                }

                                Spacer()

                                Text("\(profile.homeCards.count)/3")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(themeColor.color.opacity(0.1), in: Capsule())
                            }

                            VStack(spacing: 10) {
                                ForEach(profile.homeCards) { cardType in
                                    HStack(spacing: 12) {
                                        Image(systemName: cardType.icon)
                                            .font(.title3)
                                            .foregroundStyle(cardType.gradient ?? LinearGradient(colors: [themeColor.color], startPoint: .leading, endPoint: .trailing))
                                            .frame(width: 28)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(cardType.displayName)
                                                .font(.subheadline.weight(.medium))

                                            Text(cardType.description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Text(getValue(for: cardType))
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundStyle(themeColor.color)
                                    }
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(alignment: .topTrailing) {
                                        if editMode == .active {
                                            Button {
                                                withAnimation {
                                                    profile.removeHomeCard(cardType)
                                                    do {
                                                        try modelContext.save()
                                                    } catch {
                                                        saveErrorMessage = "Failed to remove card: \(error.localizedDescription)"
                                                        showSaveError = true
                                                    }
                                                }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(.white, .red)
                                                    .symbolRenderingMode(.palette)
                                            }
                                            .offset(x: 8, y: -8)
                                        }
                                    }
                                    .onDrag {
                                        self.draggedCard = cardType
                                        return NSItemProvider(object: cardType.rawValue as NSString)
                                    }
                                    .onDrop(of: [UTType.text], delegate: CardDropDelegate(
                                        card: cardType,
                                        cards: $profile.homeCardOrder,
                                        draggedCard: $draggedCard,
                                        modelContext: modelContext
                                    ))
                                }
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    // Available Cards
                    if !availableCards.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(themeColor.color)
                                    .frame(width: 16)

                                Text("Available Cards")
                                    .font(.headline)
                            }

                            VStack(spacing: 10) {
                                ForEach(availableCards) { cardType in
                                    Button {
                                        if profile.homeCards.count < 3 {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                profile.addHomeCard(cardType)
                                                do {
                                                    try modelContext.save()
                                                } catch {
                                                    saveErrorMessage = "Failed to add card: \(error.localizedDescription)"
                                                    showSaveError = true
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: cardType.icon)
                                                .font(.title3)
                                                .foregroundStyle(cardType.gradient ?? LinearGradient(colors: [themeColor.color], startPoint: .leading, endPoint: .trailing))
                                                .frame(width: 28)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(cardType.displayName)
                                                    .font(.subheadline.weight(.medium))
                                                    .foregroundStyle(.primary)

                                                Text(cardType.description)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            if profile.homeCards.count >= 3 {
                                                Text("Max 3")
                                                    .font(.caption)
                                                    .foregroundStyle(.tertiary)
                                            } else {
                                                Image(systemName: "plus.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(themeColor.color)
                                            }
                                        }
                                        .padding(12)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .opacity(profile.homeCards.count >= 3 ? 0.5 : 1.0)
                                    }
                                    .disabled(profile.homeCards.count >= 3)
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    // Remove All Button
                    if !profile.homeCards.isEmpty {
                        Button {
                            withAnimation {
                                profile.homeCardOrder.removeAll()
                                do {
                                    try modelContext.save()
                                } catch {
                                    saveErrorMessage = "Failed to remove all cards: \(error.localizedDescription)"
                                    showSaveError = true
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                Text("Remove All Cards")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.red.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Home Screen")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
        .toolbar {
            if !profile.homeCards.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation {
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
}

struct CardDropDelegate: DropDelegate {
    let card: StatCardType
    @Binding var cards: [String]
    @Binding var draggedCard: StatCardType?
    let modelContext: ModelContext

    func performDrop(info: DropInfo) -> Bool {
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedCard = self.draggedCard else {
            return
        }

        if draggedCard != card {
            let from = cards.firstIndex(of: draggedCard.rawValue)!
            let to = cards.firstIndex(of: card.rawValue)!
            withAnimation(.default) {
                cards.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                try? modelContext.save()
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeCardSettingsView(profile: UserProfile())
    }
    .modelContainer(for: [UserProfile.self, Book.self], inMemory: true)
}
