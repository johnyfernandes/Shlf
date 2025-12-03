//
//  HomeCardSettingsView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData

struct HomeCardSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfile
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    private var engine: GamificationEngine {
        GamificationEngine(modelContext: modelContext)
    }

    // Available cards not currently in home
    private var availableCards: [StatCardType] {
        StatCardType.allCases.filter { !profile.homeCards.contains($0) }
    }

    // Helper function to get value for each card type
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
        Form {
            Section {
                Text("Customize which stats appear on your home page. You can show up to 3 cards.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            if !profile.homeCards.isEmpty {
                Section("Active Cards (\(profile.homeCards.count)/3)") {
                    ForEach(profile.homeCards) { cardType in
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: cardType.icon)
                                .font(.title3)
                                .foregroundStyle(cardType.gradient ?? LinearGradient(colors: [profile.themeColor.color], startPoint: .leading, endPoint: .trailing))
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(cardType.displayName)
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Colors.text)

                                Text(cardType.description)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }

                            Spacer()

                            Text(getValue(for: cardType))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(profile.themeColor.color)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
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
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { from, to in
                        profile.moveHomeCard(from: from, to: to)
                        do {
                            try modelContext.save()
                        } catch {
                            saveErrorMessage = "Failed to reorder cards: \(error.localizedDescription)"
                            showSaveError = true
                        }
                    }
                }
            }

            if !availableCards.isEmpty {
                Section("Available Cards") {
                    ForEach(availableCards) { cardType in
                        Button {
                            if profile.homeCards.count < 3 {
                                withAnimation {
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
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: cardType.icon)
                                    .font(.title3)
                                    .foregroundStyle(cardType.gradient ?? LinearGradient(colors: [profile.themeColor.color], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cardType.displayName)
                                        .font(Theme.Typography.body)
                                        .foregroundStyle(Theme.Colors.text)

                                    Text(cardType.description)
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Colors.secondaryText)
                                }

                                Spacer()

                                if profile.homeCards.count >= 3 {
                                    Text("Max 3")
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Colors.tertiaryText)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(profile.themeColor.color)
                                }
                            }
                        }
                        .disabled(profile.homeCards.count >= 3)
                    }
                }
            }

            if !profile.homeCards.isEmpty {
                Section {
                    Button("Remove All Cards", role: .destructive) {
                        withAnimation {
                            profile.homeCardOrder.removeAll()
                            do {
                                try modelContext.save()
                            } catch {
                                saveErrorMessage = "Failed to remove all cards: \(error.localizedDescription)"
                                showSaveError = true
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Home Screen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !profile.homeCards.isEmpty {
                EditButton()
            }
        }
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK") {}
        } message: {
            Text(saveErrorMessage)
        }
    }
}

#Preview {
    NavigationStack {
        HomeCardSettingsView(profile: UserProfile())
    }
    .modelContainer(for: [UserProfile.self, Book.self], inMemory: true)
}
