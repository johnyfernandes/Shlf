//
//  QuickProgressStepper.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

struct QuickProgressStepper: View {
    @Environment(\.themeColor) private var themeColor
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Bindable var book: Book
    let incrementAmount: Int
    @Binding var showConfetti: Bool
    let onSave: (Int) -> Void

    @AppStorage("progressEditTooltipDismissed") private var hasDismissedEditTooltip = false
    @State private var pendingPages: Int = 0
    @State private var showSaveButton = false
    @State private var longPressTimer: Timer?
    @State private var accelerationMultiplier: Double = 1.0
    @State private var showFinishAlert = false
    @State private var isEditingPage = false
    @State private var pageText = ""
    @State private var pageFieldWidth: CGFloat = 0
    @State private var showEditTooltip = false
    @FocusState private var isPageFieldFocused: Bool

    private var totalPendingPages: Int {
        book.currentPage + pendingPages
    }

    private var totalPendingText: String {
        NumberFormatter.localizedString(from: NSNumber(value: totalPendingPages), number: .decimal)
    }

    private var pageDisplayText: String {
        if isEditingPage {
            return pageText.isEmpty ? "0" : pageText
        }
        return NumberFormatter.localizedString(from: NSNumber(value: book.currentPage), number: .decimal)
    }

    private var pageFieldWidthValue: CGFloat {
        max(56, pageFieldWidth)
    }

    private var accentBackground: Color {
        themeColor.color
    }

    private var accentForeground: Color {
        themeColor.onColor(for: colorScheme)
    }

    private var shouldShowEditTooltip: Bool {
        !hasDismissedEditTooltip && !isEditingPage && pendingPages == 0
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Compact stepper
            HStack(spacing: Theme.Spacing.md) {
                // Decrement button
                Button {
                    dismissEditTooltip()
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
                        ZStack {
                            Text(pageDisplayText)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .fixedSize(horizontal: true, vertical: false)
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear.preference(key: PageFieldWidthKey.self, value: proxy.size.width)
                                    }
                                )
                                .opacity(0)

                            if isEditingPage {
                                TextField("", text: $pageText)
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundStyle(themeColor.color)
                                    .monospacedDigit()
                                    .multilineTextAlignment(.center)
                                    .keyboardType(.numberPad)
                                    .focused($isPageFieldFocused)
                                    .frame(width: pageFieldWidthValue)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .textFieldStyle(.plain)
                                    .onSubmit {
                                        commitPageEdit()
                                    }
                                    .onChange(of: pageText) { _, newValue in
                                        let filtered = newValue.filter { $0.isNumber }
                                        if filtered != newValue {
                                            pageText = filtered
                                        }
                                        guard let total = book.totalPages,
                                              let value = Int(filtered),
                                              value > total else { return }
                                        pageText = "\(total)"
                                    }
                                    .onChange(of: isPageFieldFocused) { _, newValue in
                                        if !newValue {
                                            commitPageEdit()
                                        }
                                    }
                            } else {
                                Text(pageDisplayText)
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.Colors.text)
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        dismissEditTooltip()
                                        guard pendingPages == 0 else { return }
                                        startPageEditing()
                                    }
                            }
                        }
                        .frame(width: pageFieldWidthValue)
                        .anchorPreference(key: PageNumberBoundsKey.self, value: .bounds) { $0 }
                        .onPreferenceChange(PageFieldWidthKey.self) { width in
                            if !isEditingPage, width > 0 {
                                pageFieldWidth = width
                            }
                        }

                        if pendingPages != 0 && !isEditingPage {
                            Image(systemName: "arrow.right")
                                .font(.title3)
                                .foregroundStyle(themeColor.color)

                            Text(totalPendingText)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(themeColor.color)
                                .monospacedDigit()
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .frame(minWidth: pageFieldWidthValue)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .overlayPreferenceValue(PageNumberBoundsKey.self) { anchor in
                        GeometryReader { proxy in
                            if let anchor, showEditTooltip {
                                let rect = proxy[anchor]
                                editTooltipView
                                    .position(x: rect.midX, y: rect.minY - 32)
                            }
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pendingPages)

                    if let total = book.totalPages {
                        let clampedCurrent = min(totalPendingPages, total)
                        let percent = total > 0 ? Int((Double(clampedCurrent) / Double(total) * 100).rounded()) : 0
                        let remaining = max(0, total - clampedCurrent)

                        HStack(spacing: 4) {
                            Text(
                                String.localizedStringWithFormat(
                                    localized("Progress.PercentFormat %lld", locale: locale),
                                    percent
                                )
                            )
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(themeColor.color)

                            if remaining > 0 {
                                Text(verbatim: "•")
                                    .font(Theme.Typography.subheadline)
                                    .foregroundStyle(Theme.Colors.tertiaryText)

                                Text(
                                    String.localizedStringWithFormat(
                                        localized("Progress.LeftFormat %lld", locale: locale),
                                        remaining
                                    )
                                )
                                .font(Theme.Typography.subheadline)
                                .foregroundStyle(Theme.Colors.tertiaryText)
                            }
                        }
                    }
                }

                Spacer()

                // Increment button
                Button {
                    dismissEditTooltip()
                    incrementPage()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            themeColor == .neutral ? accentForeground : .white,
                            accentBackground
                        )
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
                    dismissEditTooltip()
                    saveProgress()
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(
                            String.localizedStringWithFormat(
                                localized(pendingPages > 0 ? "Progress.SavePlusFormat %lld" : "Progress.SaveFormat %lld", locale: locale),
                                pendingPages
                            )
                        )
                        Image(systemName: "checkmark")
                    }
                    .font(Theme.Typography.headline)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(accentForeground)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous)
                            .fill(accentBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous)
                                    .stroke(accentBackground.opacity(colorScheme == .dark ? 0.25 : 0.2), lineWidth: 1)
                            )
                    )
                    .shadow(color: accentBackground.opacity(0.3), radius: 10, y: 4)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Common.Done") {
                    commitPageEdit()
                }
            }
        }
        .onChange(of: pendingPages) { oldValue, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showSaveButton = newValue != 0
            }
        }
        .alert("Progress.Finish.Title", isPresented: $showFinishAlert) {
            Button("Progress.Finish.MarkFinished") {
                let pagesRead = pendingPages

                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    book.currentPage = totalPendingPages
                    book.readingStatus = .finished
                    book.dateFinished = Date()
                    pendingPages = 0
                    showSaveButton = false
                }

                // Delay confetti slightly for smoother transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showConfetti = true
                }

                onSave(pagesRead)
            }
            Button("Progress.Finish.KeepReading") {
                applyProgressUpdate()
            }
            Button("Common.Cancel", role: .cancel) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    pendingPages = 0
                    showSaveButton = false
                }
            }
        } message: {
                    Text(
                        String.localizedStringWithFormat(
                            localized("Progress.Finish.Message", locale: locale),
                            book.title
                        )
                    )
        }
        .onAppear {
            if shouldShowEditTooltip {
                showEditTooltip = true
            }
        }
        .onChange(of: shouldShowEditTooltip) { _, newValue in
            showEditTooltip = newValue
        }
        .onTapGesture {
            dismissEditTooltip()
        }
    }

    private var editTooltipView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(localized("Progress.Tooltip.Title", locale: locale))
                .font(.caption.weight(.bold))
            Text(localized("Progress.Tooltip.Message", locale: locale))
                .font(.caption2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(themeColor.onColor(for: colorScheme))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(themeColor.color.gradient)
                .shadow(color: themeColor.color.opacity(0.35), radius: 6, y: 4)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(themeColor.color)
                .frame(width: 10, height: 10)
                .rotationEffect(.degrees(45))
                .offset(y: 6)
        }
        .frame(maxWidth: 220, alignment: .leading)
        .allowsHitTesting(false)
    }

    private func dismissEditTooltip() {
        guard showEditTooltip else { return }
        showEditTooltip = false
        hasDismissedEditTooltip = true
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

        // Check if user reached the last page (regardless of reading status)
        // Only show finish alert if book is currently being read
        if let totalPages = book.totalPages,
           totalPendingPages >= totalPages,
           (book.readingStatus == .currentlyReading || book.readingStatus == .wantToRead) {
            showFinishAlert = true
        } else {
            applyProgressUpdate()
        }
    }

    private func applyProgressUpdate() {
        let originalCurrentPage = book.currentPage

        // CRITICAL: Clamp currentPage to valid range [0, totalPages]
        let minPage = 0
        let maxPage = book.totalPages ?? Int.max
        let clampedPage = min(maxPage, max(minPage, totalPendingPages))

        book.currentPage = clampedPage

        // Calculate ACTUAL pages read (accounting for clamping)
        let actualPagesRead = clampedPage - originalCurrentPage

        // Auto-change status to Currently Reading if needed
        // But restore saved progress first if available
        if book.readingStatus == .wantToRead && clampedPage > 0 {
            book.readingStatus = .currentlyReading
            book.dateStarted = Date()
        }

        // If book has saved progress and user is starting fresh, warn them
        // (Don't automatically restore - let user decide)
        if let saved = book.savedCurrentPage, saved > 0, originalCurrentPage == 0 {
            // User had saved progress but is starting from 0
            // Keep the current action but don't clear savedCurrentPage yet
            // User can manually restore via EditBookView if needed
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            pendingPages = 0
            showSaveButton = false
        }

        // Send ACTUAL delta to Watch (not pending, which might have been clamped)
        WatchConnectivityManager.shared.sendPageDeltaToWatch(
            bookUUID: book.id,
            delta: actualPagesRead,
            newPage: book.currentPage
        )

        // Create session with ACTUAL pages read
        onSave(actualPagesRead)
    }

    private func startPageEditing() {
        pageText = "\(totalPendingPages)"
        isEditingPage = true
        isPageFieldFocused = true
    }

    private func commitPageEdit() {
        guard isEditingPage else { return }
        let filtered = pageText.filter { $0.isNumber }
        guard !filtered.isEmpty, let value = Int(filtered) else {
            pageText = "\(totalPendingPages)"
            isEditingPage = false
            isPageFieldFocused = false
            return
        }

        let clamped = clampPage(value)
        pendingPages = clamped - book.currentPage
        pageText = "\(clamped)"
        isEditingPage = false
        isPageFieldFocused = false
    }

    private func clampPage(_ value: Int) -> Int {
        let minPage = 0
        let maxPage = book.totalPages ?? Int.max
        return min(maxPage, max(minPage, value))
    }
}

private struct PageFieldWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}

private struct PageNumberBoundsKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
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
        showConfetti: .constant(false),
        onSave: { _ in }
    )
    .padding()
}
