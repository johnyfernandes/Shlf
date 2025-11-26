//
//  QuickProgressStepper.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

struct QuickProgressStepper: View {
    @Bindable var book: Book
    let incrementAmount: Int
    let onSave: () -> Void

    @State private var pendingPages: Int = 0
    @State private var showSaveButton = false
    @State private var longPressTimer: Timer?
    @State private var accelerationMultiplier: Double = 1.0

    private var totalPendingPages: Int {
        book.currentPage + pendingPages
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Current page display with pending indicator
            HStack(spacing: Theme.Spacing.sm) {
                Text("Page")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.secondaryText)

                Text("\(book.currentPage)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.text)
                    .monospacedDigit()

                if pendingPages != 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.caption)
                        Text("\(totalPendingPages)")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Theme.Colors.primary)
                    .transition(.scale.combined(with: .opacity))
                }

                if let total = book.totalPages {
                    Text("of \(total)")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pendingPages)

            // Stepper buttons
            HStack(spacing: Theme.Spacing.lg) {
                // Decrement button
                Button {
                    decrementPage()
                } label: {
                    Image(systemName: "minus")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                .fill(pendingPages <= -incrementAmount ? Theme.Colors.error : Theme.Colors.secondaryText)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            startContinuousDecrement()
                        }
                )
                .disabled(book.currentPage + pendingPages <= 0)
                .opacity(book.currentPage + pendingPages <= 0 ? 0.5 : 1.0)

                Spacer()

                // Increment button
                Button {
                    incrementPage()
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                .fill(Theme.Colors.primary)
                        )
                        .shadow(color: Theme.Colors.primary.opacity(0.3), radius: 8, y: 4)
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            startContinuousIncrement()
                        }
                )
                .disabled(book.totalPages != nil && totalPendingPages >= book.totalPages!)
                .opacity(book.totalPages != nil && totalPendingPages >= book.totalPages! ? 0.5 : 1.0)
            }
            .padding(.horizontal, Theme.Spacing.xl)

            // Save button (appears when there are pending changes)
            if showSaveButton {
                Button {
                    saveProgress()
                } label: {
                    HStack {
                        Text(pendingPages > 0 ? "Save +\(pendingPages) pages" : "Save \(pendingPages) pages")
                            .font(Theme.Typography.headline)

                        Image(systemName: "checkmark.circle.fill")
                    }
                    .frame(maxWidth: .infinity)
                    .primaryButton()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
        .onChange(of: pendingPages) { oldValue, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showSaveButton = newValue != 0
            }
        }
    }

    private func incrementPage() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            pendingPages += incrementAmount
        }
    }

    private func decrementPage() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            pendingPages -= incrementAmount
        }
    }

    private func startContinuousIncrement() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        accelerationMultiplier = 1.0

        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            incrementPage()

            // Accelerate after 2 seconds
            accelerationMultiplier += 0.1
            if accelerationMultiplier > 3.0 {
                accelerationMultiplier = 3.0
            }
        }
    }

    private func startContinuousDecrement() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        accelerationMultiplier = 1.0

        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if book.currentPage + pendingPages > 0 {
                decrementPage()

                accelerationMultiplier += 0.1
                if accelerationMultiplier > 3.0 {
                    accelerationMultiplier = 3.0
                }
            } else {
                stopContinuousAction()
            }
        }
    }

    private func stopContinuousAction() {
        longPressTimer?.invalidate()
        longPressTimer = nil
        accelerationMultiplier = 1.0
    }

    private func saveProgress() {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        book.currentPage = totalPendingPages

        if book.readingStatus == .wantToRead && totalPendingPages > 0 {
            book.readingStatus = .currentlyReading
            book.dateStarted = Date()
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            pendingPages = 0
            showSaveButton = false
        }

        onSave()
    }
}

#Preview {
    QuickProgressStepper(
        book: Book(
            title: "Test Book",
            author: "Author",
            totalPages: 300,
            currentPage: 45
        ),
        incrementAmount: 1,
        onSave: {}
    )
    .padding()
}
