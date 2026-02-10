//
//  ProgressSliderView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

struct ProgressSliderView: View {
    @Environment(\.themeColor) private var themeColor
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Bindable var book: Book
    let incrementAmount: Int
    let showButtons: Bool
    @Binding var showConfetti: Bool
    let onSave: (Int) -> Void

    @AppStorage("progressEditTooltipDismissed") private var hasDismissedEditTooltip = false
    @State private var sliderValue: Double = 0
    @State private var isDragging = false
    @State private var showSaveButton = false
    @State private var lastHapticPage: Int = 0
    @State private var showFinishAlert = false
    @State private var isEditingPage = false
    @State private var pageText = ""
    @State private var pageFieldWidth: CGFloat = 0
    @State private var showEditTooltip = false
    @FocusState private var isPageFieldFocused: Bool

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

    private var maxSliderValue: Double {
        if let total = book.totalPages, total > 0 {
            return Double(total)
        }
        return Double(max(book.currentPage, 100))
    }

    private var sliderProgress: Double {
        let denominator = max(1, maxSliderValue)
        return min(1, max(0, sliderValue / denominator))
    }

    private var pageDisplayText: String {
        if isEditingPage {
            return pageText.isEmpty ? "0" : pageText
        }
        return NumberFormatter.localizedString(from: NSNumber(value: currentPage), number: .decimal)
    }

    private var pageFieldWidthValue: CGFloat {
        max(56, pageFieldWidth)
    }

    private var shouldShowEditTooltip: Bool {
        !hasDismissedEditTooltip && !isEditingPage
    }

    var body: some View {
        VStack(spacing: 16) {
            // Compact page display
            HStack(spacing: 12) {
                if showButtons {
                    // Decrement button
                    Button {
                        decrementPage()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(
                                sliderValue > 0 ? Theme.Colors.tertiaryText : Theme.Colors.tertiaryText.opacity(0.3),
                                Theme.Colors.secondaryBackground
                            )
                    }
                    .disabled(sliderValue <= 0)
                }

                Spacer()

                // Page display with info
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        ZStack {
                            Text(pageDisplayText)
                                .font(.system(size: 42, weight: .bold, design: .rounded))
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
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
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
                                Text(currentPage, format: .number)
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
                                    .foregroundStyle(isDragging ? themeColor.color : Theme.Colors.text)
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .contentTransition(.numericText())
                                    .animation(.snappy(duration: 0.2), value: currentPage)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        dismissEditTooltip()
                                        startPageEditing()
                                    }
                            }
                        }
                        .frame(minWidth: pageFieldWidthValue)
                        .anchorPreference(key: PageNumberBoundsKey.self, value: .bounds) { $0 }
                        .onPreferenceChange(PageFieldWidthKey.self) { width in
                            if !isEditingPage, width > 0 {
                                pageFieldWidth = width
                            }
                        }

                        if let total = book.totalPages {
                            Text(
                                String.localizedStringWithFormat(
                                    localized("/ %lld", locale: locale),
                                    total
                                )
                            )
                            .font(.title3)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .overlayPreferenceValue(PageNumberBoundsKey.self) { anchor in
                        GeometryReader { proxy in
                            if let anchor, showEditTooltip {
                                let rect = proxy[anchor]
                                editTooltipView
                                    .position(x: rect.midX, y: rect.minY - 34)
                            }
                        }
                    }

                    if let total = book.totalPages {
                        HStack(spacing: 4) {
                            Text(
                                String.localizedStringWithFormat(
                                    localized("%lld%%", locale: locale),
                                    Int(progressPercentage)
                                )
                            )
                            .font(.caption.weight(.medium))
                            .foregroundStyle(themeColor.color)
                            .contentTransition(.numericText())

                            if total > currentPage {
                                Text(verbatim: "•")
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.tertiaryText)

                                Text(
                                    String.localizedStringWithFormat(
                                        localized("%lld left", locale: locale),
                                        total - currentPage
                                    )
                                )
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.tertiaryText)
                            }
                        }
                    }
                }

                Spacer()

                if showButtons {
                    // Increment button
                    Button {
                        incrementPage()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 36))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(themeColor.onColor(for: colorScheme), themeColor.color)
                    }
                    .disabled(book.totalPages != nil && sliderValue >= Double(book.totalPages!))
                    .opacity(book.totalPages != nil && sliderValue >= Double(book.totalPages!) ? 0.3 : 1.0)
                }
            }

            // Beautiful compact slider
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        Capsule()
                            .fill(Theme.Colors.tertiaryBackground)
                            .frame(height: 6)

                        // Progress fill with gradient
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeColor.color,
                                        themeColor.color.opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * sliderProgress, height: 6)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: sliderValue)

                        // Thumb
                        Circle()
                            .fill(.white)
                            .frame(width: isDragging ? 28 : 22, height: isDragging ? 28 : 22)
                            .shadow(color: .black.opacity(0.2), radius: isDragging ? 10 : 6, y: isDragging ? 4 : 2)
                            .overlay(
                                Circle()
                                    .strokeBorder(themeColor.color, lineWidth: isDragging ? 3 : 2)
                            )
                            .offset(x: geometry.size.width * sliderProgress - (isDragging ? 14 : 11))
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
                .frame(height: 28)
            }

            // Save button
            if showSaveButton {
                Button {
                    saveProgress()
                } label: {
                    HStack(spacing: 6) {
                        if currentPage > book.currentPage {
                            Text(
                                String.localizedStringWithFormat(
                                    localized("Save +%lld pages", locale: locale),
                                    currentPage - book.currentPage
                                )
                            )
                        } else if currentPage < book.currentPage {
                            Text(
                                String.localizedStringWithFormat(
                                    localized("Save %lld pages", locale: locale),
                                    currentPage - book.currentPage
                                )
                            )
                        } else {
                            Text(localized("No changes", locale: locale))
                        }
                        Image(systemName: "checkmark")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .primaryButton(color: themeColor.color, foreground: themeColor.onColor(for: colorScheme))
                }
                .disabled(!hasChanges)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button(localized("Done", locale: locale)) {
                    commitPageEdit()
                }
            }
        }
        .onAppear {
            sliderValue = max(0, min(Double(book.currentPage), maxSliderValue))
        }
        .onChange(of: book.currentPage) { oldValue, newValue in
            if !isDragging && !showSaveButton {
                sliderValue = max(0, min(Double(newValue), maxSliderValue))
            }
        }
        .onChange(of: hasChanges) { oldValue, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showSaveButton = newValue
            }
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
        .alert("Finished Reading?", isPresented: $showFinishAlert) {
            Button("Mark as Finished") {
                let pagesRead = currentPage - book.currentPage

                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    book.currentPage = currentPage
                    book.readingStatus = .finished
                    book.dateFinished = Date()
                    showSaveButton = false
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showConfetti = true
                }

                onSave(pagesRead)
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
                    Text(
                        String.localizedStringWithFormat(
                            localized("You've reached the last page of %@. Would you like to mark it as finished?", locale: locale),
                            book.title
                        )
                    )
        }
    }

    private func handleDragChanged(_ value: DragGesture.Value, in width: CGFloat) {
        if !isDragging {
            isDragging = true
            dismissEditTooltip()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        guard width > 0 else { return }
        let maxValue = maxSliderValue
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
        dismissEditTooltip()

        if let totalPages = book.totalPages, currentPage >= totalPages && book.readingStatus == .currentlyReading {
            showFinishAlert = true
        } else {
            applyProgressUpdate()
        }
    }

    private func applyProgressUpdate() {
        dismissEditTooltip()
        let pagesRead = currentPage - book.currentPage

        book.currentPage = currentPage

        // Auto-change status to Currently Reading if needed
        if book.readingStatus == .wantToRead && currentPage > 0 {
            book.readingStatus = .currentlyReading
            book.dateStarted = Date()
        }

        // If book has saved progress, keep it for potential restoration
        // (Don't automatically clear it)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showSaveButton = false
        }

        WatchConnectivityManager.shared.sendPageDeltaToWatch(
            bookUUID: book.id,
            delta: pagesRead,
            newPage: book.currentPage
        )

        onSave(pagesRead)
    }

    private func incrementPage() {
        dismissEditTooltip()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            sliderValue = min(Double(book.totalPages ?? 100), sliderValue + Double(incrementAmount))
        }
    }

    private func decrementPage() {
        dismissEditTooltip()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            sliderValue = max(0, sliderValue - Double(incrementAmount))
        }
    }

    private func startPageEditing() {
        pageText = "\(currentPage)"
        isEditingPage = true
        isPageFieldFocused = true
    }

    private func commitPageEdit() {
        guard isEditingPage else { return }
        let filtered = pageText.filter { $0.isNumber }
        guard !filtered.isEmpty, let value = Int(filtered) else {
            pageText = "\(currentPage)"
            isEditingPage = false
            isPageFieldFocused = false
            return
        }

        let clamped = clampPage(value)
        sliderValue = Double(clamped)
        pageText = "\(clamped)"
        isEditingPage = false
        isPageFieldFocused = false
    }

    private func clampPage(_ value: Int) -> Int {
        let minPage = 0
        let maxPage = book.totalPages ?? Int.max
        return min(maxPage, max(minPage, value))
    }

    private var editTooltipView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(localized("Tap here!", locale: locale))
                .font(.caption.weight(.bold))
            Text(localized("Tap here to edit your last page for this session.", locale: locale))
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
            showConfetti: .constant(false),
            onSave: { _ in }
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
            showConfetti: .constant(false),
            onSave: { _ in }
        )
    }
    .padding()
}
