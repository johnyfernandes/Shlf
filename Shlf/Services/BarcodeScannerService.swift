//
//  BarcodeScannerService.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import VisionKit
import Vision

enum ScanError: Error {
    case cameraUnavailable
    case scanningNotSupported
    case scanCancelled
    case invalidISBN

    var localizedDescription: String {
        switch self {
        case .cameraUnavailable: return "Camera is not available"
        case .scanningNotSupported: return "Barcode scanning is not supported on this device"
        case .scanCancelled: return "Scanning was cancelled"
        case .invalidISBN: return "Invalid ISBN barcode"
        }
    }
}

@Observable
final class BarcodeScannerService: NSObject {
    var isScanning = false
    var scannedISBN: String?
    var scanError: ScanError?

    private var dataScannerVC: DataScannerViewController?
    private var continuation: CheckedContinuation<String, Error>?

    override init() {
        super.init()
    }

    // MARK: - Public API

    func scanBarcode() async throws -> String {
        guard DataScannerViewController.isSupported else {
            throw ScanError.scanningNotSupported
        }

        guard DataScannerViewController.isAvailable else {
            throw ScanError.cameraUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            startScanning()
        }
    }

    func createScannerView() -> DataScannerViewController? {
        guard DataScannerViewController.isSupported,
              DataScannerViewController.isAvailable else {
            return nil
        }

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
            isHighlightingEnabled: true
        )

        scanner.delegate = self

        self.dataScannerVC = scanner
        return scanner
    }

    // MARK: - Private Methods

    private func startScanning() {
        isScanning = true
        scannedISBN = nil
        scanError = nil

        guard let scanner = dataScannerVC else {
            continuation?.resume(throwing: ScanError.cameraUnavailable)
            continuation = nil
            return
        }

        try? scanner.startScanning()
    }

    private func stopScanning() {
        dataScannerVC?.stopScanning()
        isScanning = false
    }

    private func processBarcode(_ barcode: String) {
        // Validate ISBN format (10 or 13 digits)
        let cleanBarcode = barcode.replacingOccurrences(of: "-", with: "")

        guard cleanBarcode.count == 10 || cleanBarcode.count == 13,
              cleanBarcode.allSatisfy({ $0.isNumber || $0 == "X" }) else {
            scanError = .invalidISBN
            continuation?.resume(throwing: ScanError.invalidISBN)
            continuation = nil
            stopScanning()
            return
        }

        scannedISBN = cleanBarcode
        continuation?.resume(returning: cleanBarcode)
        continuation = nil
        stopScanning()
    }
}

// MARK: - DataScannerViewControllerDelegate

extension BarcodeScannerService: DataScannerViewControllerDelegate {
    func dataScanner(
        _ dataScanner: DataScannerViewController,
        didTapOn item: RecognizedItem
    ) {
        switch item {
        case .barcode(let barcode):
            if let payloadString = barcode.payloadStringValue {
                processBarcode(payloadString)
            }
        default:
            break
        }
    }

    func dataScanner(
        _ dataScanner: DataScannerViewController,
        didAdd addedItems: [RecognizedItem],
        allItems: [RecognizedItem]
    ) {
        // Auto-detect first barcode
        if let firstBarcode = addedItems.first(where: {
            if case .barcode = $0 { return true }
            return false
        }) {
            if case .barcode(let barcode) = firstBarcode,
               let payloadString = barcode.payloadStringValue {
                processBarcode(payloadString)
            }
        }
    }
}
