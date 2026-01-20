//
//  BarcodeScannerView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import VisionKit
import Vision

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
    let onScan: (String) -> Void

    @State private var showCameraOverlay = true
    @State private var overlayTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                DataScannerRepresentable { isbn in
                    onScan(isbn)
                    dismiss()
                }
                .ignoresSafeArea()
            } else {
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 60))
                        .foregroundStyle(Theme.Colors.tertiaryText)

                    Text("Scanner Not Available")
                        .font(Theme.Typography.title2)

                    Text("Barcode scanning is not supported on this device")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)

                    Button("Close") {
                        dismiss()
                    }
                    .primaryButton(color: themeColor.color)
                }
                .padding(Theme.Spacing.xl)
            }

            // Camera stabilization overlay
            if showCameraOverlay {
                VStack(spacing: Theme.Spacing.sm) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.1)

                    Text("Initializing Camera...")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
                .padding(.top, 18)
                .transition(.opacity)
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                    .padding(Theme.Spacing.md)
                }

                Spacer()

                ScanGuidanceOverlay()
                    .padding(.bottom, Theme.Spacing.lg)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showCameraOverlay)
        .onAppear {
            overlayTask?.cancel()
            overlayTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 700_000_000)
                showCameraOverlay = false
            }
        }
        .onDisappear {
            overlayTask?.cancel()
        }
    }
}

struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> = [
            .barcode(symbologies: [.ean13, .ean8, .upce, .code128])
        ]

        let scanner = DataScannerViewController(
            recognizedDataTypes: recognizedDataTypes,
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: false
        )

        scanner.delegate = context.coordinator

        // Start scanning immediately
        try? scanner.startScanning()

        print("✅ Scanner initialized with Coordinator delegate")

        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    // MARK: - Coordinator

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
            super.init()
            print("✅ Coordinator created")
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            print("📱 Delegate called: didAdd \(addedItems.count) items")

            // Process first barcode immediately
            for item in addedItems {
                if case .barcode(let barcode) = item,
                   let payloadString = barcode.payloadStringValue {
                    print("✅ Detected barcode: \(payloadString)")

                    // Validate ISBN format
                    let cleanBarcode = payloadString.replacingOccurrences(of: "-", with: "")

                    if cleanBarcode.count == 10 || cleanBarcode.count == 13,
                       cleanBarcode.allSatisfy({ $0.isNumber || $0 == "X" }) {
                        print("✅ Valid ISBN: \(cleanBarcode)")
                        dataScanner.stopScanning()
                        onScan(cleanBarcode)
                        return
                    } else {
                        print("⚠️ Invalid ISBN format: \(payloadString)")
                    }
                }
            }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didTapOn item: RecognizedItem
        ) {
            print("📱 Delegate called: didTapOn")

            if case .barcode(let barcode) = item,
               let payloadString = barcode.payloadStringValue {
                print("✅ Tapped barcode: \(payloadString)")

                let cleanBarcode = payloadString.replacingOccurrences(of: "-", with: "")

                if cleanBarcode.count == 10 || cleanBarcode.count == 13,
                   cleanBarcode.allSatisfy({ $0.isNumber || $0 == "X" }) {
                    dataScanner.stopScanning()
                    onScan(cleanBarcode)
                }
            }
        }

        deinit {
            print("❌ Coordinator deallocated")
        }
    }
}

private struct ScanGuidanceOverlay: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        Color.white.opacity(0.25),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 6], dashPhase: 2)
                    )

                HStack(spacing: 6) {
                    ForEach(0..<9) { _ in
                        Circle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(width: 260, height: 150)

            Text("Scan ISBN Barcode")
                .font(Theme.Typography.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

#Preview {
    BarcodeScannerView { isbn in
        print("Scanned ISBN: \(isbn)")
    }
}
