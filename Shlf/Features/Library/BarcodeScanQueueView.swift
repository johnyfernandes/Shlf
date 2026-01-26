//
//  BarcodeScanQueueView.swift
//  Shlf
//
//  Created by Codex on 19/01/2026.
//

import SwiftUI
import SwiftData
import VisionKit
import Vision

struct BarcodeScanQueueView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Environment(\.colorScheme) private var colorScheme
    @Query private var profiles: [UserProfile]
    @Query private var books: [Book]

    @Binding var selectedTab: Int
    let onDismissAll: () -> Void

    @State private var queue: [ScanQueueItem] = []
    @State private var showUpgradeAlert = false
    @State private var showUpgradeSheet = false
    @State private var isAdding = false
    @State private var showCameraOverlay = true
    @State private var overlayTask: Task<Void, Never>?
    @State private var seenISBNs: Set<String> = []

    private let bookAPI = BookAPIService()

    private var isProUser: Bool {
        ProAccess.isProUser(profile: profiles.first)
    }

    private var remainingSlots: Int {
        guard !isProUser else { return Int.max }
        return max(0, 5 - books.count)
    }

    private var readyItems: [ScanQueueItem] {
        queue.filter { $0.status == .ready }
    }

    private var canAddCount: Int {
        min(readyItems.count, remainingSlots)
    }

    private var addButtonTitle: String {
        if canAddCount == 1 {
            return String.localizedStringWithFormat(
                String(localized: "Add %lld Book"),
                canAddCount
            )
        }
        return String.localizedStringWithFormat(
            String(localized: "Add %lld Books"),
            canAddCount
        )
    }

    var body: some View {
        ZStack {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                MultiScanRepresentable { isbn in
                    handleScan(isbn)
                }
                .ignoresSafeArea()
            } else {
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 60))
                        .foregroundStyle(Theme.Colors.tertiaryText)

                    Text("Scanner Not Available")
                        .font(Theme.Typography.title2)

                    Text("Barcode scanning is not supported on this device")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)

                    Button("Close") {
                        dismiss()
                    }
                    .primaryButton(color: themeColor.color, foreground: themeColor.onColor(for: colorScheme))
                }
                .padding(Theme.Spacing.xl)
            }

            if showCameraOverlay {
                VStack(spacing: Theme.Spacing.sm) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.1)

                    Text("Initializing Camera...")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
                .padding(.top, 18)
                .transition(.opacity)
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                    .padding(Theme.Spacing.md)
                }

                Spacer()

                ScanGuidanceOverlay()
                    .padding(.bottom, 12)
            }
        }
        .safeAreaInset(edge: .bottom) {
            queuePanel
        }
        .animation(.easeInOut(duration: 0.35), value: showCameraOverlay)
        .onAppear {
            overlayTask?.cancel()
            overlayTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 700_000_000)
                showCameraOverlay = false
            }
        }
        .onDisappear {
            overlayTask?.cancel()
        }
        .alert("Upgrade Required", isPresented: $showUpgradeAlert) {
            Button("Upgrade to Pro") {
                showUpgradeSheet = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You've reached the limit of 5 books. Upgrade to Pro for unlimited books.")
        }
        .sheet(isPresented: $showUpgradeSheet) {
            PaywallView()
        }
    }

    private var queuePanel: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Scan ISBNs")
                    .font(.headline)
                Spacer()
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "Scanned %lld"),
                        queue.count
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            }

            if queue.isEmpty {
                VStack(spacing: 6) {
                    Text("No scans yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Point your camera at a barcode to queue books.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(queue) { item in
                            ScanQueueRow(
                                item: item,
                                onRemove: { removeItem(item.id) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 220)
            }

            Button {
                addQueuedBooks()
            } label: {
                Text(addButtonTitle)
                    .frame(maxWidth: .infinity)
            }
            .primaryButton(color: themeColor.color, foreground: themeColor.onColor(for: colorScheme))
            .disabled(canAddCount == 0 || isAdding)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(themeColor.color.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private func handleScan(_ isbn: String) {
        let cleanISBN = isbn.replacingOccurrences(of: "-", with: "")
        guard cleanISBN.count == 10 || cleanISBN.count == 13 else { return }
        guard seenISBNs.insert(cleanISBN).inserted else { return }

        let item = ScanQueueItem(isbn: cleanISBN, status: .fetching, bookInfo: nil)
        queue.insert(item, at: 0)

        Task {
            do {
                let bookInfo = try await bookAPI.fetchBook(isbn: cleanISBN)
                let duplicateCheck = try? BookLibraryService.checkForDuplicate(
                    title: bookInfo.title,
                    author: bookInfo.author,
                    isbn: bookInfo.isbn,
                    in: modelContext
                )

                await MainActor.run {
                    updateItem(item.id) { current in
                        current.bookInfo = bookInfo
                        if case .duplicate = duplicateCheck {
                            current.status = .duplicate
                        } else {
                            current.status = .ready
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    updateItem(item.id) { current in
                        current.status = .failed
                    }
                }
            }
        }
    }

    private func updateItem(_ id: UUID, update: (inout ScanQueueItem) -> Void) {
        guard let index = queue.firstIndex(where: { $0.id == id }) else { return }
        var item = queue[index]
        update(&item)
        queue[index] = item
    }

    private func removeItem(_ id: UUID) {
        queue.removeAll { $0.id == id }
    }

    private func addQueuedBooks() {
        guard canAddCount > 0 else {
            if !isProUser && remainingSlots == 0 {
                showUpgradeAlert = true
            }
            return
        }

        isAdding = true
        var remaining = remainingSlots

        for index in queue.indices {
            if remaining == 0 {
                if queue[index].status == .ready {
                    queue[index].status = .limitReached
                }
                continue
            }

            guard queue[index].status == .ready,
                  let info = queue[index].bookInfo else { continue }

            let duplicateCheck = try? BookLibraryService.checkForDuplicate(
                title: info.title,
                author: info.author,
                isbn: info.isbn,
                in: modelContext
            )

            if case .duplicate = duplicateCheck {
                queue[index].status = .duplicate
                continue
            }

            let resolvedSubjects = info.subjects ?? []
            let canonicalSubjects: [String]?
            if let profile = profiles.first {
                let canonical = profile.registerSubjects(resolvedSubjects)
                canonicalSubjects = canonical.isEmpty ? nil : canonical
            } else {
                canonicalSubjects = resolvedSubjects.isEmpty ? nil : resolvedSubjects
            }

            let book = Book(
                title: info.title,
                author: info.author,
                isbn: info.isbn,
                coverImageURL: info.coverImageURL,
                totalPages: info.totalPages ?? 0,
                currentPage: 0,
                bookType: .physical,
                readingStatus: .wantToRead,
                bookDescription: info.description,
                subjects: canonicalSubjects,
                publisher: info.publisher,
                publishedDate: info.publishedDate,
                language: info.language,
                openLibraryWorkID: info.workID,
                openLibraryEditionID: info.olid
            )

            modelContext.insert(book)
            queue[index].status = .added
            remaining -= 1
        }

        if let profile = profiles.first {
            let engine = GamificationEngine(modelContext: modelContext)
            engine.checkAchievements(for: profile)
        }

        WidgetDataExporter.exportSnapshot(modelContext: modelContext)
        try? modelContext.save()

        isAdding = false

        if !isProUser && remaining == 0 && queue.contains(where: { $0.status == .limitReached }) {
            showUpgradeAlert = true
        } else {
            selectedTab = 1
            onDismissAll()
        }
    }
}

private struct ScanQueueRow: View {
    @Environment(\.themeColor) private var themeColor
    let item: ScanQueueItem
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let info = item.bookInfo {
                BookCoverView(
                    imageURL: info.coverImageURL,
                    title: info.title,
                    width: 34,
                    height: 50
                )
                .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.Colors.tertiaryBackground)
                    .frame(width: 34, height: 50)
                    .overlay(
                        Image(systemName: "barcode")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.titleText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(item.subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(item.status.displayLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(item.status.displayColor(themeColor: themeColor.color))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(item.status.displayColor(themeColor: themeColor.color).opacity(0.12), in: Capsule())

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.tertiaryText)
                    .padding(6)
                    .background(Theme.Colors.tertiaryBackground, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ScanQueueItem: Identifiable {
    let id = UUID()
    let isbn: String
    var status: ScanQueueStatus
    var bookInfo: BookInfo?

    var titleText: String {
        if let info = bookInfo, !info.title.isEmpty {
            return info.title
        }
        return isbn
    }

    var subtitleText: String {
        if let info = bookInfo, !info.author.isEmpty {
            return info.author
        }
        return isbn
    }
}

private enum ScanQueueStatus {
    case fetching
    case ready
    case duplicate
    case failed
    case added
    case limitReached

    var displayLabel: LocalizedStringKey {
        switch self {
        case .fetching: return "Fetching details…"
        case .ready: return "Ready to add"
        case .duplicate: return "Already in library"
        case .failed: return "Not found"
        case .added: return "Added"
        case .limitReached: return "Free limit reached"
        }
    }

    func displayColor(themeColor: Color) -> Color {
        switch self {
        case .fetching: return Theme.Colors.secondaryText
        case .ready: return themeColor
        case .duplicate: return Theme.Colors.warning
        case .failed: return Theme.Colors.error
        case .added: return Theme.Colors.success
        case .limitReached: return Theme.Colors.warning
        }
    }
}

private struct MultiScanRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> = [
            .barcode(symbologies: [.ean13, .ean8, .upce, .code128])
        ]

        let scanner = DataScannerViewController(
            recognizedDataTypes: recognizedDataTypes,
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: false
        )

        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScan: (String) -> Void

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            for item in addedItems {
                if case .barcode(let barcode) = item,
                   let payloadString = barcode.payloadStringValue {
                    onScan(payloadString)
                }
            }
        }
    }
}

private struct ScanGuidanceOverlay: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        Color.white.opacity(0.25),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 6], dashPhase: 2)
                    )

                HStack(spacing: 6) {
                    ForEach(0..<9) { _ in
                        Circle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(width: 260, height: 150)

            Text("Scan ISBN Barcode")
                .font(Theme.Typography.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

#Preview {
    BarcodeScanQueueView(selectedTab: .constant(1), onDismissAll: {})
        .modelContainer(for: [Book.self, UserProfile.self], inMemory: true)
}
