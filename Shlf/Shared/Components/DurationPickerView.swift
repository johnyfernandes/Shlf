//
//  DurationPickerView.swift
//  Shlf
//
//  Created by Codex on 03/02/2026.
//

import SwiftUI

struct DurationPickerView: View {
    @Binding var minutes: Int
    let maxHours: Int
    let minuteStep: Int
    let showSummary: Bool

    @State private var selectedHours: Int
    @State private var selectedMinutes: Int

    init(
        minutes: Binding<Int>,
        maxHours: Int = 23,
        minuteStep: Int = 1,
        showSummary: Bool = true
    ) {
        self._minutes = minutes
        self.maxHours = maxHours
        self.minuteStep = max(1, minuteStep)
        self.showSummary = showSummary

        let clamped = DurationPickerView.clampMinutes(
            minutes.wrappedValue,
            maxHours: maxHours
        )
        _selectedHours = State(initialValue: clamped / 60)
        _selectedMinutes = State(initialValue: (clamped % 60 / self.minuteStep) * self.minuteStep)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Picker("Hours", selection: $selectedHours) {
                    ForEach(0...maxHours, id: \.self) { hour in
                        Text(
                            String.localizedStringWithFormat(
                                String(localized: "%lldh"),
                                hour
                            )
                        )
                            .tag(hour)
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                Picker("Minutes", selection: $selectedMinutes) {
                    ForEach(Array(stride(from: 0, through: 59, by: minuteStep)), id: \.self) { minute in
                        Text(
                            String.localizedStringWithFormat(
                                String(localized: "%lldm"),
                                minute
                            )
                        )
                            .tag(minute)
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .frame(height: 160)

            if showSummary {
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            syncFromMinutes()
        }
        .onChange(of: minutes) { _, _ in
            syncFromMinutes()
        }
        .onChange(of: selectedHours) { _, _ in
            updateMinutes()
        }
        .onChange(of: selectedMinutes) { _, _ in
            updateMinutes()
        }
    }

    private var summaryText: String {
        let total = selectedHours * 60 + selectedMinutes
        if total == 0 {
            return "0 min"
        }

        var parts: [String] = []
        if selectedHours > 0 {
            parts.append("\(selectedHours) \(selectedHours == 1 ? "hr" : "hrs")")
        }
        if selectedMinutes > 0 {
            parts.append("\(selectedMinutes) min")
        }
        return parts.joined(separator: " ")
    }

    private func updateMinutes() {
        let total = selectedHours * 60 + selectedMinutes
        if minutes != total {
            minutes = total
        }
    }

    private func syncFromMinutes() {
        let clamped = DurationPickerView.clampMinutes(minutes, maxHours: maxHours)
        if clamped != minutes {
            minutes = clamped
        }

        let hours = clamped / 60
        let mins = clamped % 60
        let steppedMinutes = (mins / minuteStep) * minuteStep

        if selectedHours != hours {
            selectedHours = hours
        }
        if selectedMinutes != steppedMinutes {
            selectedMinutes = steppedMinutes
        }
    }

    private static func clampMinutes(_ value: Int, maxHours: Int) -> Int {
        let maxMinutes = maxHours * 60 + 59
        return min(max(0, value), maxMinutes)
    }
}
