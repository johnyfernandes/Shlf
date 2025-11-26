//
//  ProgressSliderView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

struct ProgressSliderView: View {
    @Bindable var book: Book
    let incrementAmount: Int
    let showButtons: Bool
    let onSave: () -> Void

    @State private var sliderValue: Double = 0
    @State private var isDragging = false
    @State private var showSaveButton = false
    @State private var lastHapticPage: Int = 0
    @State private var showFinishAlert = false

    private var currentPage: Int {
        Int(sliderValue)
    }

    private var hasChanges: Bool {
        currentPage != book.currentPage
    }

    private var progressPercentage: Double {
        guard let total = book.totalPages, total > 0 else { return 0 }
        return (Double(currentPage) / Double(total)) * 100
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Page display with optional buttons
            if showButtons {
                HStack(spacing: Theme.Spacing.md) {
                    // Decrement button
                    Button {
                        decrementPage()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                sliderValue > 0 ? Theme.Colors.tertiaryText : Theme.Colors.tertiaryText.opacity(0.3),
                                Theme.Colors.secondaryBackground
                            )
                    }
                    .disabled(sliderValue <= 0)

                    VStack(spacing: Theme.Spacing.xs) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Text("\(currentPage)")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(isDragging ? Theme.Colors.primary : Theme.Colors.text)
                                .monospacedDigit()
                                .contentTransition(.numericText())

                            if let total = book.totalPages {
                                Text("/ \(total)")
                                    .font(Theme.Typography.title3)
                                    .foregroundStyle(Theme.Colors.tertiaryText)
                            }
                        }
                        .animation(.snappy(duration: 0.2), value: currentPage)

                        if book.totalPages != nil {
                            Text("\(Int(progressPercentage))% complete")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.secondaryText)
                                .contentTransition(.numericText())
                        }
                    }

                    // Increment button
                    Button {
                        incrementPage()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 40))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Theme.Colors.primary)
                    }
                    .disabled(book.totalPages != nil && sliderValue >= Double(book.totalPages!))
                    .opacity(book.totalPages != nil && sliderValue >= Double(book.totalPages!) ? 0.3 : 1.0)
                }
            } else {
                VStack(spacing: Theme.Spacing.xs) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text("\(currentPage)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(isDragging ? Theme.Colors.primary : Theme.Colors.text)
                            .monospacedDigit()
                            .contentTransition(.numericText())

                        if let total = book.totalPages {
                            Text("/ \(total)")
                                .font(Theme.Typography.title2)
                                .foregroundStyle(Theme.Colors.tertiaryText)
                        }
                    }
                    .animation(.snappy(duration: 0.2), value: currentPage)

                    if book.totalPages != nil {
                        Text("\(Int(progressPercentage))% complete")
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .contentTransition(.numericText())
                    }
                }
            }

            // Beautiful slider
            VStack(spacing: Theme.Spacing.sm) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.full, style: .continuous)
                            .fill(Theme.Colors.tertiaryBackground)
                            .frame(height: 8)

                        // Progress fill
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.full, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Theme.Colors.primary,
                                        Theme.Colors.primary.opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * (sliderValue / Double(book.totalPages ?? 1)), height: 8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: sliderValue)

                        // Thumb
                        Circle()
                            .fill(.white)
                            .frame(width: isDragging ? 32 : 24, height: isDragging ? 32 : 24)
                            .shadow(color: Theme.Shadow.large, radius: isDragging ? 12 : 8, y: isDragging ? 6 : 4)
                            .overlay(
                                Circle()
                                    .strokeBorder(Theme.Colors.primary, lineWidth: isDragging ? 3 : 2)
                            )
                            .offset(x: geometry.size.width * (sliderValue / Double(book.totalPages ?? 1)) - (isDragging ? 16 : 12))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        handleDragChanged(value, in: geometry.size.width)
                                    }
                                    .onEnded { _ in
                                        handleDragEnded()
                                    }
                            )
                    }
                }
                .frame(height: 32)

                // Page markers
                if let total = book.totalPages {
                    HStack {
                        Text("0")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText)

                        Spacer()

                        Text("\(total)")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    }
                }
            }

            // Save button
            if showSaveButton {
                Button {
                    saveProgress()
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        if currentPage > book.currentPage {
                            Text("Save +\(currentPage - book.currentPage) pages")
                        } else if currentPage < book.currentPage {
                            Text("Save \(currentPage - book.currentPage) pages")
                        } else {
                            Text("No changes")
                        }
                        Image(systemName: "checkmark")
                    }
                    .font(Theme.Typography.headline)
                    .frame(maxWidth: .infinity)
                    .primaryButton()
                }
                .disabled(!hasChanges)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
        .onAppear {
            sliderValue = Double(book.currentPage)
        }
        .onChange(of: hasChanges) { oldValue, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showSaveButton = newValue
            }
        }
        .alert("Finished Reading?", isPresented: $showFinishAlert) {
            Button("Mark as Finished") {
                book.currentPage = currentPage
                book.readingStatus = .finished
                book.dateFinished = Date()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showSaveButton = false
                }
                onSave()
            }
            Button("Keep Reading") {
                applyProgressUpdate()
            }
            Button("Cancel", role: .cancel) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showSaveButton = false
                }
            }
        } message: {
            Text("You've reached the last page of \(book.title). Would you like to mark it as finished?")
        }
    }

    private func handleDragChanged(_ value: DragGesture.Value, in width: CGFloat) {
        if !isDragging {
            isDragging = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        let maxValue = Double(book.totalPages ?? 100)
        let newValue = max(0, min(maxValue, (value.location.x / width) * maxValue))
        let roundedValue = round(newValue)

        sliderValue = roundedValue

        // Haptic feedback on page change
        let currentPageInt = Int(roundedValue)
        if currentPageInt != lastHapticPage {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            lastHapticPage = currentPageInt
        }
    }

    private func handleDragEnded() {
        isDragging = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func saveProgress() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        // Check if user reached the last page
        if let totalPages = book.totalPages, currentPage >= totalPages && book.readingStatus == .currentlyReading {
            showFinishAlert = true
        } else {
            applyProgressUpdate()
        }
    }

    private func applyProgressUpdate() {
        book.currentPage = currentPage

        if book.readingStatus == .wantToRead && currentPage > 0 {
            book.readingStatus = .currentlyReading
            book.dateStarted = Date()
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showSaveButton = false
        }

        onSave()
    }

    private func incrementPage() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            sliderValue = min(Double(book.totalPages ?? 100), sliderValue + Double(incrementAmount))
        }
    }

    private func decrementPage() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            sliderValue = max(0, sliderValue - Double(incrementAmount))
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ProgressSliderView(
            book: Book(
                title: "Test Book",
                author: "Author",
                totalPages: 300,
                currentPage: 145
            ),
            incrementAmount: 5,
            showButtons: false,
            onSave: {}
        )

        ProgressSliderView(
            book: Book(
                title: "Test Book",
                author: "Author",
                totalPages: 300,
                currentPage: 145
            ),
            incrementAmount: 5,
            showButtons: true,
            onSave: {}
        )
    }
    .padding()
}
