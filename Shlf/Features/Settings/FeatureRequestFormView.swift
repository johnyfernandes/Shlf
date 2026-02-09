//
//  FeatureRequestFormView.swift
//  Shlf
//
//  Created by João Fernandes on 09/02/2026.
//

import SwiftUI

struct FeatureRequestFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.themeColor) private var themeColor

    @State private var apiService = ShlfAPIService.shared

    @State private var title = ""
    @State private var description = ""
    @State private var category: FeatureRequestCategory = .tracking
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    let onComplete: (Bool) -> Void

    private var isValid: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5 &&
        description.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20
    }

    var body: some View {
        Form {
            Section("FeatureRequests.Form.TitleSection") {
                TextField("FeatureRequests.Form.TitlePlaceholder", text: $title, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
            }

            Section("FeatureRequests.Form.DescriptionSection") {
                TextEditor(text: $description)
                    .frame(minHeight: 140)
                Text("FeatureRequests.Form.DescriptionHint")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            Section("FeatureRequests.Form.CategorySection") {
                Picker("FeatureRequests.Form.CategoryPicker", selection: $category) {
                    ForEach(FeatureRequestCategory.allCases) { option in
                        Text(option.localizedTitle(locale: locale))
                            .tag(option)
                    }
                }
            }
        }
        .navigationTitle("FeatureRequests.Form.Title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Common.Cancel") {
                    onComplete(false)
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("FeatureRequests.Form.Submit") {
                    Task { await submit() }
                }
                .disabled(!isValid || isSubmitting)
            }
        }
        .tint(themeColor.color)
        .alert("FeatureRequests.Error.Title", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("Common.OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await apiService.submitFeatureRequest(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category.rawValue,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            )
            onComplete(true)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}