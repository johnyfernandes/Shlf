//
//  ProgressRing.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let gradient: LinearGradient
    let size: CGFloat

    init(
        progress: Double,
        lineWidth: CGFloat = 8,
        gradient: LinearGradient = Theme.Colors.xpGradient,
        size: CGFloat = 60
    ) {
        self.progress = min(max(progress, 0), 1)
        self.lineWidth = lineWidth
        self.gradient = gradient
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Theme.Colors.tertiaryBackground,
                    lineWidth: lineWidth
                )

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    gradient,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(Theme.Animation.spring, value: progress)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 40) {
        ProgressRing(progress: 0.35)

        ProgressRing(
            progress: 0.75,
            gradient: Theme.Colors.streakGradient,
            size: 80
        )

        ProgressRing(progress: 1.0)
    }
    .padding()
}
