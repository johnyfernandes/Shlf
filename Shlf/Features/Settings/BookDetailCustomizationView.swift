//
//  BookDetailCustomizationView.swift
//  Shlf
//
//  Customize book detail page sections
//

import SwiftUI
import SwiftData

struct BookDetailCustomizationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Bindable var profile: UserProfile
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    @State private var editMode: EditMode = .inactive

    private var activeSections: [BookDetailSection] {
        profile.bookDetailSections.filter { profile.isBookDetailSectionVisible($0) }
    }

    private var availableSections: [BookDetailSection] {
        BookDetailSection.allCases.filter { section in
            !profile.bookDetailSections.contains(section) || !profile.isBookDetailSectionVisible(section)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Dynamic gradient background
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
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.fill")
                                .font(.caption)
                                .foregroundStyle(themeColor.color)
                                .frame(width: 16)

                            Text("About")
                                .font(.headline)
                        }

                        Text("Customize which sections appear on book detail pages and their order. Drag to reorder sections.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Active Sections
                    if !activeSections.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "list.bullet")
                                        .font(.caption)
                                        .foregroundStyle(themeColor.color)
                                        .frame(width: 16)

                                    Text("Active Sections")
                                        .font(.headline)
                                }

                                Spacer()

                                Text("\(activeSections.count)/\(BookDetailSection.allCases.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(themeColor.color.opacity(0.1), in: Capsule())
                            }

                            VStack(spacing: 10) {
                                ForEach(activeSections) { section in
                                    HStack(spacing: 12) {
                                        // Drag handle
                                        if editMode == .active {
                                            Image(systemName: "line.3.horizontal")
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }

                                        Image(systemName: section.icon)
                                            .font(.title3)
                                            .foregroundStyle(themeColor.color)
                                            .frame(width: 28)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(section.displayName)
                                                .font(.subheadline.weight(.medium))

                                            Text(section.description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        // Toggle for optional sections
                                        Toggle("", isOn: toggleBinding(for: section))
                                            .labelsHidden()
                                            .tint(themeColor.color)
                                    }
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(alignment: .topTrailing) {
                                        if editMode == .active && canRemoveSection(section) {
                                            Button {
                                                withAnimation {
                                                    disableSection(section)
                                                    do {
                                                        try modelContext.save()
                                                    } catch {
                                                        saveErrorMessage = "Failed to update: \(error.localizedDescription)"
                                                        showSaveError = true
                                                    }
                                                }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(.white, .red)
                                                    .symbolRenderingMode(.palette)
                                            }
                                            .offset(x: 8, y: -8)
                                        }
                                    }
                                }
                                .onMove { from, to in
                                    profile.moveBookDetailSection(from: from, to: to)
                                    do {
                                        try modelContext.save()
                                    } catch {
                                        saveErrorMessage = "Failed to reorder: \(error.localizedDescription)"
                                        showSaveError = true
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    // Available Sections
                    if !availableSections.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(themeColor.color)
                                    .frame(width: 16)

                                Text("Hidden Sections")
                                    .font(.headline)
                            }

                            VStack(spacing: 10) {
                                ForEach(availableSections) { section in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            enableSection(section)
                                            do {
                                                try modelContext.save()
                                            } catch {
                                                saveErrorMessage = "Failed to add section: \(error.localizedDescription)"
                                                showSaveError = true
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: section.icon)
                                                .font(.title3)
                                                .foregroundStyle(.tertiary)
                                                .frame(width: 28)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(section.displayName)
                                                    .font(.subheadline.weight(.medium))
                                                    .foregroundStyle(.primary)

                                                Text(section.description)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            Image(systemName: "plus.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(themeColor.color)
                                        }
                                        .padding(12)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .opacity(0.7)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    // Reset Button
                    Button {
                        resetToDefault()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Default")
                        }
                        .font(.headline)
                        .foregroundStyle(themeColor.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(themeColor.color.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Book Details")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation {
                        editMode = editMode == .active ? .inactive : .active
                    }
                } label: {
                    Text(editMode == .active ? "Done" : "Edit")
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColor.color)
                }
            }
        }
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK") {}
        } message: {
            Text(saveErrorMessage)
        }
    }

    // MARK: - Helper Methods

    private func toggleBinding(for section: BookDetailSection) -> Binding<Bool> {
        Binding(
            get: {
                switch section {
                case .description: return profile.showDescription
                case .lastPosition: return true
                case .quotes: return true
                case .notes: return profile.showNotes
                case .subjects: return profile.showSubjects
                case .metadata: return profile.showMetadata
                case .readingHistory: return profile.showReadingHistory
                }
            },
            set: { newValue in
                withAnimation {
                    switch section {
                    case .description:
                        profile.showDescription = newValue
                    case .notes:
                        profile.showNotes = newValue
                    case .subjects:
                        profile.showSubjects = newValue
                    case .metadata:
                        profile.showMetadata = newValue
                    case .readingHistory:
                        profile.showReadingHistory = newValue
                    case .lastPosition, .quotes:
                        break // Always on
                    }
                    do {
                        try modelContext.save()
                    } catch {
                        saveErrorMessage = "Failed to save: \(error.localizedDescription)"
                        showSaveError = true
                    }
                }
            }
        )
    }

    private func canRemoveSection(_ section: BookDetailSection) -> Bool {
        // Last Position and Quotes can't be removed, only toggled off
        return section != .lastPosition && section != .quotes
    }

    private func enableSection(_ section: BookDetailSection) {
        switch section {
        case .description:
            profile.showDescription = true
        case .notes:
            profile.showNotes = true
        case .subjects:
            profile.showSubjects = true
        case .metadata:
            profile.showMetadata = true
        case .readingHistory:
            profile.showReadingHistory = true
        case .lastPosition, .quotes:
            break
        }
    }

    private func disableSection(_ section: BookDetailSection) {
        switch section {
        case .description:
            profile.showDescription = false
        case .notes:
            profile.showNotes = false
        case .subjects:
            profile.showSubjects = false
        case .metadata:
            profile.showMetadata = false
        case .readingHistory:
            profile.showReadingHistory = false
        case .lastPosition, .quotes:
            break
        }
    }

    private func resetToDefault() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            profile.bookDetailSectionOrder = [
                BookDetailSection.description.rawValue,
                BookDetailSection.lastPosition.rawValue,
                BookDetailSection.quotes.rawValue,
                BookDetailSection.notes.rawValue,
                BookDetailSection.subjects.rawValue,
                BookDetailSection.metadata.rawValue,
                BookDetailSection.readingHistory.rawValue
            ]
            profile.showDescription = true
            profile.showNotes = true
            profile.showSubjects = true
            profile.showMetadata = true
            profile.showReadingHistory = true

            do {
                try modelContext.save()
            } catch {
                saveErrorMessage = "Failed to reset: \(error.localizedDescription)"
                showSaveError = true
            }
        }
    }
}

#Preview {
    @Previewable @Query var profiles: [UserProfile]

    if let profile = profiles.first {
        NavigationStack {
            BookDetailCustomizationView(profile: profile)
        }
        .modelContainer(for: [UserProfile.self, Book.self], inMemory: true)
    } else {
        Text("No profile")
            .modelContainer(for: [UserProfile.self, Book.self], inMemory: true)
    }
}
