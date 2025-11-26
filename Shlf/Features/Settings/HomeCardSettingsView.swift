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
                                .foregroundStyle(cardType.gradient ?? LinearGradient(colors: [Theme.Colors.primary], startPoint: .leading, endPoint: .trailing))
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
                                .foregroundStyle(Theme.Colors.primary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    profile.removeHomeCard(cardType)
                                    try? modelContext.save()
                                }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { from, to in
                        profile.moveHomeCard(from: from, to: to)
                        try? modelContext.save()
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
                                    try? modelContext.save()
                                }
                            }
                        } label: {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: cardType.icon)
                                    .font(.title3)
                                    .foregroundStyle(cardType.gradient ?? LinearGradient(colors: [Theme.Colors.primary], startPoint: .leading, endPoint: .trailing))
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
                                        .foregroundStyle(Theme.Colors.primary)
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
                            try? modelContext.save()
                        }
                    }
                }
            }
        }
        .navigationTitle("Home Page Cards")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HomeCardSettingsView(profile: UserProfile())
    }
    .modelContainer(for: [UserProfile.self, Book.self], inMemory: true)
}
