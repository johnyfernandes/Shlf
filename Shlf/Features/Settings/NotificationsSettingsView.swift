//
//  NotificationsSettingsView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData
import UserNotifications

struct NotificationsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var profile: UserProfile

    @State private var showPermissionAlert = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { profile.streakReminderEnabled },
                    set: { handleReminderToggle($0) }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notifications.StreakReminder.Title")
                            .font(.subheadline.weight(.medium))
                        Text("Notifications.StreakReminder.Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if profile.streakReminderEnabled {
                    DatePicker(
                        "Notifications.StreakReminder.Time",
                        selection: Binding(
                            get: { reminderDateValue },
                            set: { handleTimeChange($0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
            } header: {
                Text("Notifications.Section")
            }
        }
        .navigationTitle("Notifications.Section")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Notifications.Permission.Title", isPresented: $showPermissionAlert) {
            Button("Notifications.Permission.OpenSettings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Notifications.Permission.NotNow", role: .cancel) {}
        } message: {
            Text("Notifications.Permission.Message")
        }
    }

    private var reminderDateValue: Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = profile.streakReminderHour
        components.minute = profile.streakReminderMinute
        return calendar.date(from: components) ?? now
    }

    private func handleReminderToggle(_ isOn: Bool) {
        Task { @MainActor in
            if isOn {
                let granted = await NotificationScheduler.shared.requestAuthorization()
                if granted {
                    profile.streakReminderEnabled = true
                    await NotificationScheduler.shared.refreshSchedule(for: profile)
                    try? modelContext.save()
                } else {
                    profile.streakReminderEnabled = false
                    showPermissionAlert = true
                }
            } else {
                profile.streakReminderEnabled = false
                await NotificationScheduler.shared.cancelReminder()
                try? modelContext.save()
            }
        }
    }

    private func handleTimeChange(_ newDate: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: newDate)
        profile.streakReminderHour = components.hour ?? 21
        profile.streakReminderMinute = components.minute ?? 0

        Task { @MainActor in
            await NotificationScheduler.shared.refreshSchedule(for: profile)
            try? modelContext.save()
        }
    }

}
