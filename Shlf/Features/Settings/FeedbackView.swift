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
            Section {
                Picker(selection: $category) {
                    ForEach(FeedbackCategory.allCases) { option in
                        Text(option.localizedTitle(locale: locale))
                            .tag(option)
                    }
                } label: {
                    Text(verbatim: localized("Feedback.Form.Category", locale: locale))
                }
            } header: {
                Text(verbatim: localized("Feedback.Form.Category", locale: locale))
            }

            Section {
                TextEditor(text: $message)
                    .frame(minHeight: 160)

                Text(verbatim: localized("Feedback.Form.Limit", locale: locale))
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            } header: {
                Text(verbatim: localized("Feedback.Form.Message", locale: locale))
            }

            Section {
                RatingPicker(selected: $rating)
            } header: {
                Text(verbatim: localized("Feedback.Form.Rating", locale: locale))
            }
        }
        .navigationTitle(Text(verbatim: localized("Feedback.Title", locale: locale)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await submit() }
                } label: {
                    Text(verbatim: localized("Feedback.Form.Submit", locale: locale))
                }
                .disabled(!isValid || isSubmitting)
            }
        }
        .tint(themeColor.color)
        .alert(Text(verbatim: localized("Feedback.Error.Title", locale: locale)), isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button(role: .cancel) {
            } label: {
                Text(verbatim: localized("Common.OK", locale: locale))
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(Text(verbatim: localized("Feedback.Success.Title", locale: locale)), isPresented: $showSuccess) {
            Button {
                dismiss()
            } label: {
                Text(verbatim: localized("Common.OK", locale: locale))
            }
        } message: {
            Text(verbatim: localized("Feedback.Success.Message", locale: locale))
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
    @Environment(\.locale) private var locale

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
                Button {
                    selected = nil
                } label: {
                    Text(verbatim: localized("Common.Clear", locale: locale))
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
