//
//  FeatureRequestsView.swift
//  Shlf
//
//  Created by João Fernandes on 09/02/2026.
//

import SwiftUI

struct FeatureRequestsView: View {
    @Environment(\.themeColor) private var themeColor
    @Environment(\.locale) private var locale

    @State private var apiService = ShlfAPIService.shared
    @State private var requests: [FeatureRequest] = []
    @State private var isLoading = false
    @State private var showNewRequestSheet = false
    @State private var errorMessage: String?

    @State private var page = 1
    @State private var totalPages = 1
    @State private var sortOption: FeatureSortOption = .popular

    private let pageSize = 50

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("FeatureRequests.Description")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.secondaryText)

                    Picker("FeatureRequests.Sort", selection: $sortOption) {
                        ForEach(FeatureSortOption.allCases) { option in
                            Text(option.localizedTitle(locale: locale))
                                .tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.vertical, Theme.Spacing.xs)
            }

            Section {
                ForEach(sortedRequests) { request in
                    NavigationLink {
                        FeatureRequestDetailView(request: request) {
                            handleVote($0)
                        }
                    } label: {
                        FeatureRequestRow(request: request) { vote in
                            handleVote(vote, for: request)
                        }
                    }
                }

                if canLoadMore {
                    Button {
                        Task { await loadMore() }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("FeatureRequests.LoadMore")
                                    .font(.subheadline)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("FeatureRequests.Title")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewRequestSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .tint(themeColor.color)
        .overlay {
            if isLoading && requests.isEmpty {
                ProgressView()
            }
        }
        .alert("FeatureRequests.Error.Title", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("Common.OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showNewRequestSheet) {
            NavigationStack {
                FeatureRequestFormView { didSubmit in
                    showNewRequestSheet = false
                    if didSubmit {
                        Task { await reload() }
                    }
                }
            }
        }
        .task {
            await reload()
        }
    }

    private var sortedRequests: [FeatureRequest] {
        switch sortOption {
        case .popular:
            return requests.sorted { $0.score > $1.score }
        case .newest:
            return requests.sorted { $0.createdAt > $1.createdAt }
        case .upvotes:
            return requests.sorted { $0.upvotes > $1.upvotes }
        case .downvotes:
            return requests.sorted { $0.downvotes > $1.downvotes }
        }
    }

    private var canLoadMore: Bool {
        page < totalPages
    }

    private func reload() async {
        page = 1
        totalPages = 1
        requests = []
        await loadMore()
    }

    @MainActor
    private func loadMore() async {
        guard !isLoading else { return }
        isLoading = true
        do {
            let deviceId = DeviceIdentifier.current()
            let response = try await apiService.fetchFeatureRequests(
                deviceId: deviceId,
                category: nil,
                page: page,
                limit: pageSize
            )
            requests.append(contentsOf: response.data)
            page = response.pagination.page
            totalPages = response.pagination.pages
            if page < totalPages {
                page += 1
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func handleVote(_ vote: FeatureVote) {
        handleVote(vote, for: vote.request)
    }

    private func handleVote(_ vote: FeatureVote, for request: FeatureRequest) {
        guard let index = requests.firstIndex(where: { $0.id == request.id }) else { return }
        let original = requests[index]
        let updated = applyVote(to: original, vote: vote.isUpvote)
        requests[index] = updated

        Task {
            do {
                let deviceId = DeviceIdentifier.current()
                _ = try await apiService.voteFeatureRequest(id: request.id, deviceId: deviceId, vote: vote.isUpvote)
            } catch {
                await MainActor.run {
                    requests[index] = original
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func applyVote(to request: FeatureRequest, vote: Bool) -> FeatureRequest {
        var updated = request
        switch (request.myVote, vote) {
        case (.none, true):
            updated.upvotes += 1
            updated.myVote = true
        case (.none, false):
            updated.downvotes += 1
            updated.myVote = false
        case (.some(true), true):
            updated.upvotes = max(0, updated.upvotes - 1)
            updated.myVote = nil
        case (.some(false), false):
            updated.downvotes = max(0, updated.downvotes - 1)
            updated.myVote = nil
        case (.some(true), false):
            updated.upvotes = max(0, updated.upvotes - 1)
            updated.downvotes += 1
            updated.myVote = false
        case (.some(false), true):
            updated.downvotes = max(0, updated.downvotes - 1)
            updated.upvotes += 1
            updated.myVote = true
        }
        return updated
    }
}

private struct FeatureRequestRow: View {
    let request: FeatureRequest
    let onVote: (FeatureVote) -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(request.title)
                .font(.headline)

            Text(request.description)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.secondaryText)
                .lineLimit(2)

            HStack(spacing: Theme.Spacing.m) {
                Text(FeatureRequestCategory.localizedTitle(for: request.category, locale: locale))
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)

                Spacer()

                VoteButtons(myVote: request.myVote, upvotes: request.upvotes, downvotes: request.downvotes) { isUpvote in
                    onVote(FeatureVote(request: request, isUpvote: isUpvote))
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

private struct VoteButtons: View {
    let myVote: Bool?
    let upvotes: Int
    let downvotes: Int
    let onVote: (Bool) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Button {
                onVote(true)
            } label: {
                Label("\(upvotes)", systemImage: myVote == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)

            Button {
                onVote(false)
            } label: {
                Label("\(downvotes)", systemImage: myVote == false ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
        }
        .font(.caption)
        .foregroundStyle(Theme.Colors.secondaryText)
    }
}

private struct FeatureVote {
    let request: FeatureRequest
    let isUpvote: Bool
}

enum FeatureSortOption: String, CaseIterable, Identifiable {
    case popular
    case newest
    case upvotes
    case downvotes

    var id: String { rawValue }

    func localizedTitle(locale: Locale) -> String {
        localized("FeatureRequests.Sort.\(rawValue.capitalized)", locale: locale)
    }
}

enum FeatureRequestCategory: String, CaseIterable, Identifiable {
    case tracking
    case discovery
    case stats
    case social
    case widgets
    case sync
    case design
    case other

    var id: String { rawValue }

    func localizedTitle(locale: Locale) -> String {
        localized("FeatureRequests.Category.\(rawValue.capitalized)", locale: locale)
    }

    static func localizedTitle(for rawValue: String, locale: Locale) -> String {
        FeatureRequestCategory(rawValue: rawValue)?.localizedTitle(locale: locale) ?? rawValue
    }
}
