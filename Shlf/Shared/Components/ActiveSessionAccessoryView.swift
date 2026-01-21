//
//  ActiveSessionAccessoryView.swift
//  Shlf
//
//  Created by Codex on 19/01/2026.
//

import SwiftUI
import UIKit

/// A compact "Now Playing" style accessory view for the tab bar
/// that displays when a reading session is active.
struct ActiveSessionAccessoryView: View {
    @Environment(\.themeColor) private var themeColor
    let session: ActiveReadingSession
    let book: Book
    let coverImage: UIImage?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Book cover thumbnail
                coverThumbnail

                // Title and author
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(book.author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Timer display
                VStack(alignment: .trailing, spacing: 2) {
                    if session.isPaused {
                        Text("Paused")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    }

                    timerText
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var coverThumbnail: some View {
        ZStack {
            if let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(Theme.Colors.secondaryBackground)
                    .overlay(
                        Image(systemName: "book.closed")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText.opacity(0.6))
                    )
            }
        }
        .frame(width: 28, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
    }

    @ViewBuilder
    private var timerText: some View {
        if session.isPaused {
            // Show frozen time when paused
            Text(formattedElapsed)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(themeColor.color)
        } else {
            // Live counting timer
            Text(timerStartDate, style: .timer)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(themeColor.color)
        }
    }

    /// Calculate the effective timer start date accounting for paused duration
    private var timerStartDate: Date {
        session.startDate.addingTimeInterval(session.totalPausedDuration)
    }

    /// Format elapsed seconds for paused state
    private var formattedElapsed: String {
        let elapsed = session.elapsedTime
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
