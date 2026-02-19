//
//  AppIconSettingsView.swift
//  Shlf
//
//  Created by João Fernandes on 12/01/2026.
//

import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct AppIconSettingsView: View {
    @Environment(\.themeColor) private var themeColor
    @Bindable var profile: UserProfile
    @State private var currentIconName: String?
    @State private var isUpdating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showUpgradeSheet = false
    private let simulatorIconKey = "Shlf.simulatorAppIconName"

    private let columns = [
        GridItem(.adaptive(minimum: 90), spacing: 16)
    ]

    private var isProUser: Bool {
        ProAccess.isProUser(profile: profile)
    }

    private var supportsAlternateIcons: Bool {
        #if canImport(UIKit)
        return UIApplication.shared.supportsAlternateIcons
        #else
        return false
        #endif
    }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    themeColor.color.opacity(0.12),
                    themeColor.color.opacity(0.04),
                    Theme.Colors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "app.fill")
                                .font(.caption)
                                .foregroundStyle(themeColor.color)
                                .frame(width: 16)

                            Text("AppIconSettings.About.Title")
                                .font(.headline)
                        }

                        Text("AppIconSettings.About.Body")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if !supportsAlternateIcons {
                            Text("AppIconSettings.About.Unsupported")
                                .font(.subheadline)
                                .foregroundStyle(Theme.Colors.warning)
                        }

                        if !isProUser {
                            Text("AppIconSettings.About.ProNote")
                                .font(.subheadline)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 16) {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(AppIconOption.allCases) { option in
                                AppIconOptionView(
                                    option: option,
                                    isSelected: isSelected(option),
                                    isLocked: !isProUser && !option.isFree,
                                    onSelect: { select(option) }
                                )
                                .disabled(!supportsAlternateIcons || isUpdating)
                            }
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("AppIconSettings.Title")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            currentIconName = currentAlternateIconName()
        }
        .alert("AppIconSettings.Alert.Title", isPresented: $showError) {
            Button("Common.OK", role: .cancel) {}
        } message: {
            Text(errorMessage.isEmpty ? "AppIconSettings.Alert.Message" : errorMessage)
        }
        .sheet(isPresented: $showUpgradeSheet) {
            PaywallView()
        }
    }

    private func isSelected(_ option: AppIconOption) -> Bool {
        currentIconName == option.iconName
    }

    private func select(_ option: AppIconOption) {
        guard supportsAlternateIcons else { return }
        guard isProUser || option.isFree else {
            showUpgradeSheet = true
            return
        }
        guard currentIconName != option.iconName else { return }
        guard !isUpdating else { return }

        isUpdating = true

        #if canImport(UIKit)
        #if targetEnvironment(simulator)
        if let iconName = option.iconName {
            UserDefaults.standard.set(iconName, forKey: simulatorIconKey)
        } else {
            UserDefaults.standard.removeObject(forKey: simulatorIconKey)
        }
        currentIconName = option.iconName
        isUpdating = false
        #else
        UIApplication.shared.setAlternateIconName(option.iconName) { error in
            DispatchQueue.main.async {
                isUpdating = false
                if let error {
                    errorMessage = error.localizedDescription
                    showError = true
                } else {
                    currentIconName = option.iconName
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }
        #endif
        #else
        isUpdating = false
        #endif
    }

    private func currentAlternateIconName() -> String? {
        #if canImport(UIKit)
        #if targetEnvironment(simulator)
        return UserDefaults.standard.string(forKey: simulatorIconKey)
        #else
        return UIApplication.shared.alternateIconName
        #endif
        #else
        return nil
        #endif
    }
}

private struct AppIconOptionView: View {
    let option: AppIconOption
    let isSelected: Bool
    let isLocked: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(option.previewTint.opacity(0.18))
                        .frame(width: 64, height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(isSelected ? Color.white : .clear, lineWidth: 3)
                        )

                    if let previewImage = option.previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        Image(systemName: "books.vertical.fill")
                            .font(.title3)
                            .foregroundStyle(option.previewTint)
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .symbolRenderingMode(.hierarchical)
                    }

                    OptionBadge(
                        text: option.isFree ? "Common.Free" : "Common.Pro",
                        icon: option.isFree ? nil : "crown.fill",
                        tint: option.isFree ? Theme.Colors.success : Color.yellow
                    )
                    .offset(x: 6, y: -6)
                }
                .shadow(
                    color: isSelected ? option.previewTint.opacity(0.4) : .black.opacity(0.08),
                    radius: isSelected ? 16 : 4,
                    y: isSelected ? 6 : 2
                )
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                Text(option.displayNameKey)
                    .font(.caption)
                    .foregroundStyle(isSelected ? option.previewTint : .primary)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
        }
        .buttonStyle(.plain)
    }
}

private enum AppIconOption: String, CaseIterable, Identifiable {
    case orange
    case yellow
    case gray
    case pink
    case purple
    case black
    case blue
    case red
    case green
    case white

    var id: String { rawValue }

    var displayNameKey: LocalizedStringKey {
        switch self {
        case .orange:
            return "Orange"
        case .yellow:
            return "Yellow"
        case .gray:
            return "Gray"
        case .pink:
            return "Pink"
        case .purple:
            return "Purple"
        case .black:
            return "Black"
        case .blue:
            return "Blue"
        case .red:
            return "Red"
        case .green:
            return "Green"
        case .white:
            return "White"
        }
    }

    var iconName: String? {
        switch self {
        case .orange:
            return nil
        case .yellow:
            return "AppIcon-Yellow"
        case .gray:
            return "AppIcon-Gray"
        case .pink:
            return "AppIcon-Pink"
        case .purple:
            return "AppIcon-Purple"
        case .black:
            return "AppIcon-Black"
        case .blue:
            return "AppIcon-Blue"
        case .red:
            return "AppIcon-Red"
        case .green:
            return "AppIcon-Green"
        case .white:
            return "AppIcon-White"
        }
    }

    var isDefault: Bool {
        self == .orange
    }

    var isFree: Bool {
        switch self {
        case .orange, .blue, .green:
            return true
        default:
            return false
        }
    }

    var previewAssetName: String {
        switch self {
        case .orange:
            return "AppIconPreview-Orange"
        case .yellow:
            return "AppIconPreview-Yellow"
        case .gray:
            return "AppIconPreview-Gray"
        case .pink:
            return "AppIconPreview-Pink"
        case .purple:
            return "AppIconPreview-Purple"
        case .black:
            return "AppIconPreview-Black"
        case .blue:
            return "AppIconPreview-Blue"
        case .red:
            return "AppIconPreview-Red"
        case .green:
            return "AppIconPreview-Green"
        case .white:
            return "AppIconPreview-White"
        }
    }

    var previewTint: Color {
        switch self {
        case .orange:
            return .orange
        case .yellow:
            return .yellow
        case .gray:
            return .gray
        case .pink:
            return .pink
        case .purple:
            return .purple
        case .black:
            return .black
        case .blue:
            return .blue
        case .red:
            return .red
        case .green:
            return .green
        case .white:
            return .white
        }
    }

    var previewImage: UIImage? {
        #if canImport(UIKit)
        return UIImage(named: previewAssetName)
        #else
        return nil
        #endif
    }
}

private struct OptionBadge: View {
    let text: LocalizedStringKey
    let icon: String?
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(tint, in: Capsule())
        .shadow(color: tint.opacity(0.25), radius: 4, y: 2)
    }
}

#Preview {
    NavigationStack {
        AppIconSettingsView(profile: UserProfile())
    }
    .modelContainer(for: [UserProfile.self], inMemory: true)
}
