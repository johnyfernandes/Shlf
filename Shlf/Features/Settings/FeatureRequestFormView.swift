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
            Section {
                TextField(text: $title, axis: .vertical) {
                    Text(verbatim: localized("FeatureRequests.Form.TitlePlaceholder", locale: locale))
                }
                .textInputAutocapitalization(.sentences)
            } header: {
                Text(verbatim: localized("FeatureRequests.Form.TitleSection", locale: locale))
            }

            Section {
                TextEditor(text: $description)
                    .frame(minHeight: 140)
                Text(verbatim: localized("FeatureRequests.Form.DescriptionHint", locale: locale))
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            } header: {
                Text(verbatim: localized("FeatureRequests.Form.DescriptionSection", locale: locale))
            }

            Section {
                Picker(selection: $category) {
                    ForEach(FeatureRequestCategory.allCases) { option in
                        Text(option.localizedTitle(locale: locale))
                            .tag(option)
                    }
                } label: {
                    Text(verbatim: localized("FeatureRequests.Form.CategoryPicker", locale: locale))
                }
            } header: {
                Text(verbatim: localized("FeatureRequests.Form.CategorySection", locale: locale))
            }
        }
        .navigationTitle(Text(verbatim: localized("FeatureRequests.Form.Title", locale: locale)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onComplete(false)
                    dismiss()
                } label: {
                    Text(verbatim: localized("Common.Cancel", locale: locale))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await submit() }
                } label: {
                    Text(verbatim: localized("FeatureRequests.Form.Submit", locale: locale))
                }
                .disabled(!isValid || isSubmitting)
            }
        }
        .tint(themeColor.color)
        .alert(Text(verbatim: localized("FeatureRequests.Error.Title", locale: locale)), isPresented: Binding(
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
