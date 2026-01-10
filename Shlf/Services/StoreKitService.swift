//
//  StoreKitService.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import Foundation
import StoreKit

enum StoreError: Error {
    case failedVerification
    case purchaseFailed
    case productNotFound

    var localizedDescription: String {
        switch self {
        case .failedVerification: return "Purchase verification failed"
        case .purchaseFailed: return "Purchase failed"
        case .productNotFound: return "Product not found"
        }
    }
}

@Observable
final class StoreKitService {
    static let shared = StoreKitService()

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs = Set<String>()
    private(set) var isLoadingProducts = false
    private(set) var lastLoadError: String?

    private var productIDs: [String] = ["shlf_pro_lifetime"]
    private var updates: Task<Void, Never>?

    private init() {
        updates = observeTransactionUpdates()
        Task {
            await updatePurchasedProducts()
        }
    }

    deinit {
        updates?.cancel()
    }

    // MARK: - Public API

    var isProUser: Bool {
        !purchasedProductIDs.isEmpty
    }

    @MainActor
    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        lastLoadError = nil
        defer { isLoadingProducts = false }

        // Retry up to 3 times with exponential backoff
        for attempt in 1...3 {
            do {
                products = try await Product.products(for: productIDs)
                if !products.isEmpty {
                    return // Success, exit early
                }
                lastLoadError = "Products unavailable. Check App Store Connect or network."
            } catch {
                print("Failed to load products (attempt \(attempt)/3): \(error)")
                lastLoadError = error.localizedDescription

                if attempt < 3 {
                    // Exponential backoff: 1s, 2s
                    let delay = UInt64(attempt * 1_000_000_000) // nanoseconds
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }

        // All retries failed - products will remain empty
        print("All product loading attempts failed")
    }

    @MainActor
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updatePurchasedProducts()

        case .userCancelled:
            throw StoreError.purchaseFailed

        case .pending:
            break

        @unknown default:
            break
        }
    }

    @MainActor
    func restorePurchases() async {
        await updatePurchasedProducts()
    }

    @MainActor
    func refreshEntitlements() async {
        await updatePurchasedProducts()
    }

    // MARK: - Private Methods

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }

    @MainActor
    private func updatePurchasedProducts() async {
        var purchasedIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }

        purchasedProductIDs = purchasedIDs
        ProAccess.setCachedIsPro(!purchasedIDs.isEmpty)
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}
