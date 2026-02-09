//
//  ShlfAPIService.swift
//  Shlf
//
//  Created by João Fernandes on 09/02/2026.
//

import Foundation
import Observation

struct ShlfAPIError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

struct ShlfAPIErrorResponse: Codable {
    let error: String
    let message: String?
    let details: [String: [String]]?
}

@Observable
final class ShlfAPIService {
    static let shared = ShlfAPIService()

    private let baseURL = URL(string: "https://api.shlf.app")!
    private let urlSession: URLSession
    private let apiKey: String

    init(urlSession: URLSession = .shared, apiKey: String? = Bundle.main.object(forInfoDictionaryKey: "SHLF_API_KEY") as? String) {
        self.urlSession = urlSession
        self.apiKey = apiKey ?? ""
    }

    func submitFeedback(
        category: String,
        message: String,
        rating: Int?,
        appVersion: String?,
        deviceModel: String?,
        osVersion: String?
    ) async throws {
        let body = FeedbackPayload(
            category: category,
            message: message,
            rating: rating,
            appVersion: appVersion,
            deviceModel: deviceModel,
            osVersion: osVersion
        )
        _ = try await sendRequest(
            path: "/feedback",
            method: "POST",
            body: try JSONEncoder().encode(body)
        )
    }

    func submitFeatureRequest(
        title: String,
        description: String,
        category: String,
        appVersion: String?
    ) async throws {
        let body = FeatureRequestPayload(
            title: title,
            description: description,
            category: category,
            appVersion: appVersion
        )
        _ = try await sendRequest(
            path: "/feature-requests",
            method: "POST",
            body: try JSONEncoder().encode(body)
        )
    }

    func fetchFeatureRequests(
        deviceId: String?,
        category: String?,
        page: Int,
        limit: Int
    ) async throws -> FeatureRequestPage {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let deviceId {
            queryItems.append(URLQueryItem(name: "deviceId", value: deviceId))
        }

        if let category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }

        let data = try await sendRequest(
            path: "/feature-requests",
            method: "GET",
            queryItems: queryItems
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(FeatureRequestPage.self, from: data)
    }

    func voteFeatureRequest(id: String, deviceId: String, vote: Bool) async throws -> FeatureRequestVoteResponse {
        let body = FeatureVotePayload(deviceId: deviceId, vote: vote)
        let data = try await sendRequest(
            path: "/feature-requests/\(id)/vote",
            method: "POST",
            body: try JSONEncoder().encode(body)
        )
        return try JSONDecoder().decode(FeatureRequestVoteResponse.self, from: data)
    }

    private func sendRequest(
        path: String,
        method: String,
        body: Data? = nil,
        queryItems: [URLQueryItem] = []
    ) async throws -> Data {
        guard !apiKey.isEmpty else {
            throw ShlfAPIError(message: "Missing API key.")
        }

        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw ShlfAPIError(message: "Invalid request.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.httpBody = body

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ShlfAPIError(message: "Invalid response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let decoder = JSONDecoder()
            if let errorResponse = try? decoder.decode(ShlfAPIErrorResponse.self, from: data) {
                let fallbackMessage = errorResponse.message ?? errorResponse.error
                throw ShlfAPIError(message: fallbackMessage)
            }
            throw ShlfAPIError(message: "Server error (\(httpResponse.statusCode)).")
        }

        return data
    }
}

private struct FeedbackPayload: Codable {
    let category: String
    let message: String
    let rating: Int?
    let appVersion: String?
    let deviceModel: String?
    let osVersion: String?
}

private struct FeatureRequestPayload: Codable {
    let title: String
    let description: String
    let category: String
    let appVersion: String?
}

private struct FeatureVotePayload: Codable {
    let deviceId: String
    let vote: Bool
}
