//
//  FeatureRequest.swift
//  Shlf
//
//  Created by João Fernandes on 09/02/2026.
//

import Foundation

struct FeatureRequest: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String
    let category: String
    let createdAt: Date
    var upvotes: Int
    var downvotes: Int
    var myVote: Bool?

    var score: Int {
        upvotes - downvotes
    }
}

struct FeatureRequestPage: Codable {
    let data: [FeatureRequest]
    let pagination: FeatureRequestPagination
}

struct FeatureRequestPagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let pages: Int
}

struct FeatureRequestVoteResponse: Codable {
    let success: Bool
    let action: String
}
