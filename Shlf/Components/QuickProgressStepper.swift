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
        VStack(spacing: Theme.Spacing.lg) {
            // Compact stepper
            HStack(spacing: Theme.Spacing.md) {
                // Decrement button
                Button {
                    decrementPage()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(
                            pendingPages < 0 ? Theme.Colors.error : Theme.Colors.tertiaryText,
                            Theme.Colors.secondaryBackground
                        )
                }
                .onLongPressGesture(minimumDuration: 0.5, pressing: { isPressing in
                    if isPressing {
                        startContinuousDecrement()
                    } else {
                        stopContinuousAction()
                    }
                }, perform: {})
                .disabled(book.currentPage + pendingPages <= 0)
                .opacity(book.currentPage + pendingPages <= 0 ? 0.3 : 1.0)

                Spacer()

                // Page display
                VStack(spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(book.currentPage)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.text)
                            .monospacedDigit()

                        if pendingPages != 0 {
                            Image(systemName: "arrow.right")
                                .font(.title3)
                                .foregroundStyle(Theme.Colors.primary)

                            Text("\(totalPendingPages)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Colors.primary)
                                .monospacedDigit()
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pendingPages)

                    if let total = book.totalPages {
                        Text("of \(total)")
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    }
                }

                Spacer()

                // Increment button
                Button {
                    incrementPage()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Theme.Colors.primary)
                }
                .onLongPressGesture(minimumDuration: 0.5, pressing: { isPressing in
                    if isPressing {
                        startContinuousIncrement()
                    } else {
                        stopContinuousAction()
                    }
                }, perform: {})
                .disabled(book.totalPages != nil && totalPendingPages >= book.totalPages!)
                .opacity(book.totalPages != nil && totalPendingPages >= book.totalPages! ? 0.3 : 1.0)
            }

            // Save button (appears when there are pending changes)
            if showSaveButton {
                Button {
                    saveProgress()
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(pendingPages > 0 ? "Save +\(pendingPages) pages" : "Save \(pendingPages) pages")
                        Image(systemName: "checkmark")
                    }
                    .font(Theme.Typography.headline)
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
