//
//  BookDetailCustomizationView.swift
//  Shlf
//
//  Customize book detail page sections
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BookDetailCustomizationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Bindable var profile: UserProfile
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    @State private var editMode: EditMode = .inactive
    @State private var draggedSection: BookDetailSection?

    private var activeSectionCount: Int {
        let count = profile.bookDetailSections.filter { section in
            profile.isBookDetailSectionVisible(section)
        }.count
        return count
    }

    var body: some View {
        ZStack(alignment: .top) {
            backgroundGradient
            contentView
        }
        .navigationTitle("Book Details")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                editButton
            }
        }
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK") {}
        } message: {
            Text(saveErrorMessage)
        }
    }

    private var backgroundGradient: some View {
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
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                aboutSection
                sectionsListView
                resetButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private var aboutSection: some View {
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
    }

    private var sectionsListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                        .font(.caption)
                        .foregroundStyle(themeColor.color)
                        .frame(width: 16)

                    Text("Sections")
                        .font(.headline)
                }

                Spacer()

                Text("\(activeSectionCount)/\(BookDetailSection.allCases.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeColor.color.opacity(0.1), in: Capsule())
            }

            VStack(spacing: 10) {
                ForEach(profile.bookDetailSections) { section in
                    sectionRow(section)
                        .onDrag {
                            self.draggedSection = section
                            return NSItemProvider(object: section.rawValue as NSString)
                        }
                        .onDrop(of: [UTType.text], delegate: SectionDropDelegate(
                            section: section,
                            sections: $profile.bookDetailSectionOrder,
                            draggedSection: $draggedSection,
                            modelContext: modelContext
                        ))
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionRow(_ section: BookDetailSection) -> some View {
        let isVisible = profile.isBookDetailSectionVisible(section)

        return HStack(spacing: 12) {
            if editMode == .active {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.tertiaryText)
            }

            Image(systemName: section.icon)
                .font(.title3)
                .foregroundStyle(isVisible ? themeColor.color : Theme.Colors.tertiaryText)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(section.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isVisible ? Theme.Colors.text : Theme.Colors.secondaryText)

                Text(section.description)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            Spacer()

            Toggle("", isOn: toggleBinding(for: section))
                .labelsHidden()
                .tint(themeColor.color)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(isVisible ? 1.0 : 0.5)
    }

    private var resetButton: some View {
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

    private var editButton: some View {
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

struct SectionDropDelegate: DropDelegate {
    let section: BookDetailSection
    @Binding var sections: [String]
    @Binding var draggedSection: BookDetailSection?
    let modelContext: ModelContext

    func performDrop(info: DropInfo) -> Bool {
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedSection = self.draggedSection else {
            return
        }

        if draggedSection != section {
            let from = sections.firstIndex(of: draggedSection.rawValue)!
            let to = sections.firstIndex(of: section.rawValue)!
            withAnimation(.default) {
                sections.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                try? modelContext.save()
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
