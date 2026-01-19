//
//  BookStatCardView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

struct BookStatCardView: View {
    @Environment(\.themeColor) private var themeColor
    let title: Text
    let indicator: BookStatIndicator
    let accent: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    title
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Colors.text)
                        .lineLimit(2)
                }

                Spacer()

                HStack(spacing: 10) {
                    BookStatIndicatorView(indicator: indicator, accent: accent)

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.Colors.tertiaryText)
                }
            }
            .padding(14)
            .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(themeColor.color.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Theme.Shadow.small, radius: 3, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}

private struct BookStatIndicatorView: View {
    let indicator: BookStatIndicator
    let accent: Color

    var body: some View {
        switch indicator {
        case .bars:
            HStack(spacing: 4) {
                Capsule()
                    .fill(accent.opacity(0.5))
                    .frame(width: 4, height: 10)
                Capsule()
                    .fill(accent)
                    .frame(width: 4, height: 18)
                Capsule()
                    .fill(accent.opacity(0.7))
                    .frame(width: 4, height: 14)
            }
        case .line:
            Image(systemName: "waveform.path.ecg")
                .font(.title3)
                .foregroundStyle(accent)
        case .dot:
            Circle()
                .fill(accent.opacity(0.2))
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .fill(accent)
                        .frame(width: 8, height: 8)
                )
        case .flame:
            Image(systemName: "flame.fill")
                .font(.title3)
                .foregroundStyle(accent)
        case .speed:
            Image(systemName: "speedometer")
                .font(.title3)
                .foregroundStyle(accent)
        case .calendar:
            Image(systemName: "calendar")
                .font(.title3)
                .foregroundStyle(accent)
        case .history:
            Image(systemName: "clock.arrow.circlepath")
                .font(.title3)
                .foregroundStyle(accent)
        case .clock:
            Image(systemName: "clock.fill")
                .font(.title3)
                .foregroundStyle(accent)
        case .book:
            Image(systemName: "book.closed.fill")
                .font(.title3)
                .foregroundStyle(accent)
        }
    }
}
