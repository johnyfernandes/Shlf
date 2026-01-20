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
    @Bindable var goal: ReadingGoal
    @Bindable var profile: UserProfile

    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
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

                Section("Progress") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack {
                            Text(
                                String.localizedStringWithFormat(
                                    String(localized: "%lld/%lld"),
                                    goal.currentValue,
                                    goal.targetValue
                                )
                            )
                            + Text(verbatim: " ")
                            + Text(goal.type.unitTextKey)
                                .font(Theme.Typography.title3)

                            Spacer()

                            (
                                Text(Int(goal.progressPercentage), format: .number)
                                + Text(verbatim: "%")
                            )
                            .font(Theme.Typography.title2)
                            .foregroundStyle(goal.isCompleted ? Theme.Colors.success : themeColor.color)
                        }

                        ProgressView(value: goal.progressPercentage, total: 100)
                            .tint(goal.isCompleted ? Theme.Colors.success : themeColor.color)
                    }

                    Stepper(value: $goal.currentValue, in: 0...goal.targetValue) {
                        Text("Current Progress")
                        + Text(verbatim: ": ")
                        + Text(goal.currentValue, format: .number)
                    }
                    .font(Theme.Typography.body)
                }

                Section("Target") {
                    Stepper(value: $goal.targetValue, in: max(1, goal.currentValue)...1000) {
                        Text("Target")
                        + Text(verbatim: ": ")
                        + Text(goal.targetValue, format: .number)
                        + Text(verbatim: " ")
                        + Text(goal.type.unitTextKey)
                    }
                    .font(Theme.Typography.body)
                }

                Section("Timeline") {
                    HStack {
                        Text("Start Date")
                        Spacer()
                        Text(goal.startDate, style: .date)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }

                    DatePicker("End Date", selection: $goal.endDate, in: goal.startDate..., displayedComponents: .date)

                    if let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: goal.endDate).day {
                        HStack {
                            Text(goal.type.isDaily ? "Daily Reset" : "Days Remaining")
                            Spacer()
                            if goal.type.isDaily {
                                Text("Resets at midnight")
                                    .foregroundStyle(themeColor.color)
                            } else if daysLeft >= 0 {
                                Text(
                                    String.localizedStringWithFormat(
                                        String(localized: "%lld days"),
                                        daysLeft
                                    )
                                )
                                    .foregroundStyle(themeColor.color)
                            } else {
                                Text("Expired")
                                    .foregroundStyle(Theme.Colors.error)
                            }
                        }
                    }
                }

                Section("Status") {
                    Toggle("Mark as Completed", isOn: $goal.isCompleted)
                }

            }
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
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
                            Label("Delete Goal", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(themeColor.color)
                    }
                }
            }
            .alert("Delete Goal?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteGoal()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete this goal and cannot be undone.")
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
