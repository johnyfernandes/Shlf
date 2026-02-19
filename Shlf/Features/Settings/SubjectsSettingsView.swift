//
//  SubjectsSettingsView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData

struct SubjectsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Environment(\.locale) private var locale
    @Bindable var profile: UserProfile
    @Query private var books: [Book]

    @State private var newSubject = ""
    @State private var subjectToRename: String?
    @State private var renameText = ""
    @State private var showRenameAlert = false
    @State private var subjectToDelete: String?
    @State private var showDeleteAlert = false

    var body: some View {
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
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(themeColor.color)
                                .frame(width: 16)

                            Text("Subjects.About.Title")
                                .font(.headline)
                        }

                        Text("Subjects.About.Body")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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

                            Text("Subjects.Add.Title")
                                .font(.headline)
                        }

                        HStack(spacing: 12) {
                            TextField("Subjects.Add.Placeholder", text: $newSubject)
                                .textInputAutocapitalization(.words)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                            Button {
                                addSubject()
                            } label: {
                                Text("Subjects.Add.Action")
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

                    if profile.subjectLibrary.isEmpty {
                        InlineEmptyStateView(
                            icon: "tag",
                            title: "Subjects.Empty.Title",
                            message: "Subjects.Empty.Message"
                        )
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "tag.fill")
                                        .font(.caption)
                                        .foregroundStyle(themeColor.color)
                                        .frame(width: 16)

                                    Text("Subjects.List.Title")
                                        .font(.headline)
                                }

                                Spacer()

                                Text(verbatim: "\(profile.subjectLibrary.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(themeColor.color.opacity(0.1), in: Capsule())
                            }

                            VStack(spacing: 10) {
                                ForEach(profile.subjectLibrary, id: \.self) { subject in
                                    HStack(spacing: 12) {
                                        Image(systemName: "tag")
                                            .font(.caption)
                                            .foregroundStyle(themeColor.color)
                                            .frame(width: 16)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(subject)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(Theme.Colors.text)

                                            Text(
                                                String.localizedStringWithFormat(
                                                    localized("Subjects.BooksCountFormat %lld", locale: locale),
                                                    bookCount(for: subject)
                                                )
                                            )
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Menu {
                                            Button("Common.Rename") {
                                                beginRename(subject)
                                            }
                                            Button("Common.Delete", role: .destructive) {
                                                subjectToDelete = subject
                                                showDeleteAlert = true
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis.circle")
                                                .foregroundStyle(Theme.Colors.secondaryText)
                                        }
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 12)
                                    .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Subjects.Title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            profile.syncSubjects(from: books)
            saveChanges()
        }
        .alert("Subjects.Rename.Title", isPresented: $showRenameAlert) {
            TextField("Subjects.Rename.Placeholder", text: $renameText)
            Button("Common.Save") {
                applyRename()
            }
            Button("Common.Cancel", role: .cancel) {}
        } message: {
            Text("Subjects.Rename.Message")
        }
        .alert("Subjects.Delete.Title", isPresented: $showDeleteAlert) {
            Button("Common.Delete", role: .destructive) {
                deleteSubject()
            }
            Button("Common.Cancel", role: .cancel) {}
        } message: {
            Text("Subjects.Delete.Message")
        }
    }

    private func addSubject() {
        guard let _ = profile.addSubject(newSubject) else { return }
        newSubject = ""
        saveChanges()
    }

    private func beginRename(_ subject: String) {
        subjectToRename = subject
        renameText = subject
        showRenameAlert = true
    }

    private func applyRename() {
        guard let subject = subjectToRename else { return }
        _ = profile.renameSubject(subject, to: renameText, in: books)
        subjectToRename = nil
        renameText = ""
        saveChanges()
    }

    private func deleteSubject() {
        guard let subject = subjectToDelete else { return }
        profile.removeSubject(subject, from: books)
        subjectToDelete = nil
        saveChanges()
    }

    private func bookCount(for subject: String) -> Int64 {
        let key = UserProfile.normalizedSubjectKey(subject)
        let count = books.filter { book in
            guard let subjects = book.subjects else { return false }
            return subjects.contains(where: { UserProfile.normalizedSubjectKey($0) == key })
        }.count
        return Int64(count)
    }

    private func saveChanges() {
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        SubjectsSettingsView(profile: UserProfile())
            .modelContainer(for: [UserProfile.self, Book.self], inMemory: true)
    }
}
