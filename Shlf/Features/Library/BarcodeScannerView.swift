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
                Color.black
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: Theme.Spacing.lg) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .scaleEffect(1.5)

                            Text("Initializing Camera...")
                                .font(Theme.Typography.body)
                                .foregroundStyle(.white)
                        }
                    }
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

                if !showCameraOverlay {
                    Text("Scan ISBN Barcode")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(.white)
                        .padding(Theme.Spacing.sm)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                        .padding(Theme.Spacing.lg)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showCameraOverlay)
        .onAppear {
            // Hide overlay after camera has time to stabilize
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showCameraOverlay = false
            }
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
            qualityLevel: .fast,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
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

#Preview {
    BarcodeScannerView { isbn in
        print("Scanned ISBN: \(isbn)")
    }
}
