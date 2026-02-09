//
//  FeatureRequestDetailView.swift
//  Shlf
//
//  Created by João Fernandes on 09/02/2026.
//

import SwiftUI

struct FeatureRequestDetailView: View {
    let request: FeatureRequest
    let onVote: (FeatureVote) -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Text(request.title)
                    .font(.title2.bold())

                Text(FeatureRequestCategory.localizedTitle(for: request.category, locale: locale))
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryText)

                Text(request.description)
                    .font(.body)
                    .foregroundStyle(Theme.Colors.primaryText)

                HStack(spacing: Theme.Spacing.m) {
                    VoteButtons(myVote: request.myVote, upvotes: request.upvotes, downvotes: request.downvotes) { isUpvote in
                        onVote(FeatureVote(request: request, isUpvote: isUpvote))
                    }

                    Spacer()
                }
                .padding(.top, Theme.Spacing.s)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.l)
        }
        .navigationTitle("FeatureRequests.DetailTitle")
        .navigationBarTitleDisplayMode(.inline)
    }
}