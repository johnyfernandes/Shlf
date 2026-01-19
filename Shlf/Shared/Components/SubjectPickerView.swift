//
//  SubjectPickerView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData

struct SubjectPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Query private var books: [Book]
    @Bindable var profile: UserProfile
    @Binding var selectedSubjects: [String]

    @State private var newSubject = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [
                        themeColor.color.opacity(0.12),
                        themeColor.color.opacity(0.04),
                        Theme.Colors.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "tag.fill")
                                    .font(.caption)
                                    .foregroundStyle(themeColor.color)
                                    .frame(width: 16)

                                Text("Selected")
                                    .font(.headline)
                            }

                            if selectedSubjects.isEmpty {
                                InlineEmptyStateView(
                                    icon: "tag",
                                    title: "No subjects selected",
                                    message: "Choose from your library or add a new subject."
                                )
                            } else {
                                FlowLayout(spacing: 8) {
                                    ForEach(selectedSubjects, id: \.self) { subject in
                                        HStack(spacing: 6) {
                                            Text(subject)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(themeColor.color)
                                            Button {
                                                toggleSubject(subject)
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(themeColor.color)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(themeColor.color.opacity(0.12), in: Capsule())
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(themeColor.color)
                                    .frame(width: 16)

                                Text("Add Subject")
                                    .font(.headline)
                            }

                            HStack(spacing: 12) {
                                TextField("New subject", text: $newSubject)
                                    .textInputAutocapitalization(.words)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                                Button {
                                    addNewSubject()
                                } label: {
                                    Text("Add")
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(themeColor.color.opacity(0.2), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .disabled(UserProfile.cleanedSubjectName(newSubject).isEmpty)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "list.bullet")
                                    .font(.caption)
                                    .foregroundStyle(themeColor.color)
                                    .frame(width: 16)

                                Text("All Subjects")
                                    .font(.headline)
                            }

                            if profile.subjectLibrary.isEmpty {
                                InlineEmptyStateView(
                                    icon: "tag",
                                    title: "No subjects yet",
                                    message: "Create your first subject to get started."
                                )
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(profile.subjectLibrary, id: \.self) { subject in
                                        Button {
                                            toggleSubject(subject)
                                        } label: {
                                            HStack(spacing: 12) {
                                                Image(systemName: "tag")
                                                    .font(.caption)
                                                    .foregroundStyle(themeColor.color)
                                                    .frame(width: 16)

                                                Text(subject)
                                                    .font(.subheadline.weight(.medium))
                                                    .foregroundStyle(.primary)

                                                Spacer()

                                                if isSelected(subject) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(themeColor.color)
                                                }
                                            }
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 12)
                                            .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Subjects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        finalizeSelection()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(themeColor.color)
                }
            }
            .onAppear {
                profile.syncSubjects(from: books)
                selectedSubjects = profile.registerSubjects(selectedSubjects)
                saveChanges()
            }
        }
    }

    private func isSelected(_ subject: String) -> Bool {
        let key = UserProfile.normalizedSubjectKey(subject)
        return selectedSubjects.contains(where: { UserProfile.normalizedSubjectKey($0) == key })
    }

    private func toggleSubject(_ subject: String) {
        let key = UserProfile.normalizedSubjectKey(subject)
        if let index = selectedSubjects.firstIndex(where: { UserProfile.normalizedSubjectKey($0) == key }) {
            selectedSubjects.remove(at: index)
        } else {
            selectedSubjects.append(subject)
        }
        selectedSubjects = profile.registerSubjects(selectedSubjects)
        saveChanges()
    }

    private func addNewSubject() {
        guard let canonical = profile.addSubject(newSubject) else { return }
        newSubject = ""
        if !isSelected(canonical) {
            selectedSubjects.append(canonical)
        }
        selectedSubjects = profile.registerSubjects(selectedSubjects)
        saveChanges()
    }

    private func finalizeSelection() {
        selectedSubjects = profile.registerSubjects(selectedSubjects)
        saveChanges()
    }

    private func saveChanges() {
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        SubjectPickerView(profile: UserProfile(), selectedSubjects: .constant(["Business", "Finance"]))
            .modelContainer(for: [UserProfile.self, Book.self], inMemory: true)
    }
}
