//
//  FeedbackView.swift
//  Shlf
//
//  Created by João Fernandes on 09/02/2026.
//

import SwiftUI
import StoreKit
import UIKit

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.themeColor) private var themeColor
    @Environment(\.requestReview) private var requestReview

    @State private var apiService = ShlfAPIService.shared

    @State private var category: FeedbackCategory = .general
    @State private var message = ""
    @State private var rating: Int?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    private var isValid: Bool {
        message.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 &&
        message.count <= 5000
    }

    var body: some View {
        Form {
            Section("Feedback.Form.Category") {
                Picker("Feedback.Form.Category", selection: $category) {
                    ForEach(FeedbackCategory.allCases) { option in
                        Text(option.localizedTitle(locale: locale))
                            .tag(option)
                    }
                }
            }

            Section("Feedback.Form.Message") {
                TextEditor(text: $message)
                    .frame(minHeight: 160)

                Text("Feedback.Form.Limit")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            Section("Feedback.Form.Rating") {
                RatingPicker(selected: $rating)
            }
        }
        .navigationTitle("Feedback.Title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Feedback.Form.Submit") {
                    Task { await submit() }
                }
                .disabled(!isValid || isSubmitting)
            }
        }
        .tint(themeColor.color)
        .alert("Feedback.Error.Title", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("Common.OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Feedback.Success.Title", isPresented: $showSuccess) {
            Button("Common.OK") {
                dismiss()
            }
        } message: {
            Text("Feedback.Success.Message")
        }
    }

    @MainActor
    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
            try await apiService.submitFeedback(
                category: category.rawValue,
                message: trimmedMessage,
                rating: rating,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                deviceModel: UIDevice.current.model,
                osVersion: UIDevice.current.systemVersion
            )
            showSuccess = true
            requestReview()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct RatingPicker: View {
    @Binding var selected: Int?

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    selected = value
                } label: {
                    Image(systemName: value <= (selected ?? 0) ? "star.fill" : "star")
                        .foregroundStyle(value <= (selected ?? 0) ? Color.yellow : Theme.Colors.secondaryText)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if selected != nil {
                Button("Common.Clear") {
                    selected = nil
                }
                .font(.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
    }
}

enum FeedbackCategory: String, CaseIterable, Identifiable {
    case bug
    case ui
    case performance
    case general
    case content
    case sync

    var id: String { rawValue }

    func localizedTitle(locale: Locale) -> String {
        localized("Feedback.Category.\(rawValue.capitalized)", locale: locale)
    }
}