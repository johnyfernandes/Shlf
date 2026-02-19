//
//  EditGoalView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData

struct EditGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Environment(\.locale) private var locale
    @Bindable var goal: ReadingGoal
    @Bindable var profile: UserProfile

    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Goals.Section.Goal") {
                    HStack {
                        Label(goal.type.displayNameKey, systemImage: goal.type.icon)
                        Spacer()
                        if goal.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.Colors.success)
                        }
                    }
                    .font(Theme.Typography.headline)
                }

                Section("Goals.Section.Progress") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack {
                            Text(
                                String.localizedStringWithFormat(
                                    localized("Goals.ProgressValueFormat", locale: locale),
                                    goal.currentValue,
                                    goal.targetValue,
                                    goal.type.unitText(locale: locale)
                                )
                            )
                            .font(Theme.Typography.title3)

                            Spacer()

                            Text(
                                String.localizedStringWithFormat(
                                    localized("Goals.PercentFormat", locale: locale),
                                    Int(goal.progressPercentage)
                                )
                            )
                            .font(Theme.Typography.title2)
                            .foregroundStyle(goal.isCompleted ? Theme.Colors.success : themeColor.color)
                        }

                        ProgressView(value: goal.progressPercentage, total: 100)
                            .tint(goal.isCompleted ? Theme.Colors.success : themeColor.color)
                    }

                    Stepper(value: $goal.currentValue, in: 0...goal.targetValue) {
                        Text(
                            String.localizedStringWithFormat(
                                localized("Goals.CurrentProgressFormat", locale: locale),
                                goal.currentValue
                            )
                        )
                    }
                    .font(Theme.Typography.body)
                }

                Section("Goals.Target") {
                    Stepper(value: $goal.targetValue, in: max(1, goal.currentValue)...1000) {
                        Text(
                            String.localizedStringWithFormat(
                                localized("Goals.TargetFormat", locale: locale),
                                goal.targetValue,
                                goal.type.unitText(locale: locale)
                            )
                        )
                    }
                    .font(Theme.Typography.body)
                }

                Section("Goals.Section.Timeline") {
                    HStack {
                        Text("Goals.StartDate")
                        Spacer()
                        Text(goal.startDate, style: .date)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }

                    DatePicker("Goals.EndDate", selection: $goal.endDate, in: goal.startDate..., displayedComponents: .date)

                    if let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: goal.endDate).day {
                        HStack {
                            Text(goal.type.isDaily ? "Goals.DailyReset" : "Goals.DaysRemaining")
                            Spacer()
                            if goal.type.isDaily {
                                Text("Goals.ResetsAtMidnight")
                                    .foregroundStyle(themeColor.color)
                            } else if daysLeft >= 0 {
                                Text(
                                    String.localizedStringWithFormat(
                                        localized("Goals.DaysFormat", locale: locale),
                                        daysLeft
                                    )
                                )
                                    .foregroundStyle(themeColor.color)
                            } else {
                                Text("Goals.Expired")
                                    .foregroundStyle(Theme.Colors.error)
                            }
                        }
                    }
                }

                Section("Goals.Section.Status") {
                    Toggle("Goals.MarkCompleted", isOn: $goal.isCompleted)
                }

            }
            .navigationTitle("Goals.EditTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Common.Done") {
                        // Persist manual adjustment relative to auto-tracked baseline
                        let tracker = GoalTracker(modelContext: modelContext)
                        let baseValue = tracker.baseProgress(for: goal, profile: profile)
                        goal.manualAdjustment = goal.currentValue - baseValue

                        // CRITICAL: Save all changes before dismissing
                        try? modelContext.save()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Goals.Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(themeColor.color)
                    }
                }
            }
            .alert("Goals.Delete.Title", isPresented: $showDeleteAlert) {
                Button("Common.Delete", role: .destructive) {
                    deleteGoal()
                }
                Button("Common.Cancel", role: .cancel) { }
            } message: {
                Text("Goals.Delete.Message")
            }
        }
    }

    private func deleteGoal() {
        if let index = (profile.readingGoals ?? []).firstIndex(where: { $0.id == goal.id }) {
            profile.readingGoals?.remove(at: index)
        }
        modelContext.delete(goal)

        // CRITICAL: Save so deletion persists
        try? modelContext.save()

        dismiss()
    }
}

#Preview {
    EditGoalView(
        goal: ReadingGoal(
            type: .booksPerMonth,
            targetValue: 10,
            currentValue: 5,
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        ),
        profile: UserProfile()
    )
    .modelContainer(for: [ReadingGoal.self, UserProfile.self], inMemory: true)
}
