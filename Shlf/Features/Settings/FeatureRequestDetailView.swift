//
//  FeatureRequestDetailView.swift
//  Shlf
//
//  Created by João Fernandes on 09/02/2026.
//

import SwiftUI

struct FeatureRequestDetailView: View {
    @State private var request: FeatureRequest
    let onVote: (FeatureVote) -> Void

    @Environment(\.locale) private var locale

    init(request: FeatureRequest, onVote: @escaping (FeatureVote) -> Void) {
        _request = State(initialValue: request)
        self.onVote = onVote
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(request.title)
                    .font(.title2.bold())

                Text(FeatureRequestCategory.localizedTitle(for: request.category, locale: locale))
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryText)

                Text(request.description)
                    .font(.body)
                    .foregroundStyle(Theme.Colors.text)

                HStack(spacing: Theme.Spacing.md) {
                    VoteButtons(myVote: request.myVote, upvotes: request.upvotes, downvotes: request.downvotes) { isUpvote in
                        request = applyVote(to: request, vote: isUpvote)
                        onVote(FeatureVote(request: request, isUpvote: isUpvote))
                    }

                    Spacer()
                }
                .padding(.top, Theme.Spacing.sm)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
        }
        .navigationTitle("FeatureRequests.DetailTitle")
        .navigationBarTitleDisplayMode(.inline)
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