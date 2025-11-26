//
//  BarcodeScannerView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import VisionKit

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: (String) -> Void

    @State private var scanner = BarcodeScannerService()

    var body: some View {
        ZStack {
            if let scannerVC = scanner.createScannerView() {
                DataScannerRepresentable(scanner: scannerVC)
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
                    .primaryButton()
                }
                .padding(Theme.Spacing.xl)
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

                Text("Scan ISBN Barcode")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(.white)
                    .padding(Theme.Spacing.sm)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                    .padding(Theme.Spacing.lg)
            }
        }
        .task {
            do {
                let isbn = try await scanner.scanBarcode()
                onScan(isbn)
                dismiss()
            } catch {
                print("Scan error: \(error)")
                dismiss()
            }
        }
    }
}

struct DataScannerRepresentable: UIViewControllerRepresentable {
    let scanner: DataScannerViewController

    func makeUIViewController(context: Context) -> DataScannerViewController {
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}
}

#Preview {
    BarcodeScannerView { isbn in
        print("Scanned ISBN: \(isbn)")
    }
}
