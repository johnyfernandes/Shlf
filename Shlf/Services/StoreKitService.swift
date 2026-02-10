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

    static let monthlyProductID = "shlf_pro_monthly"
    static let yearlyProductID = "shlf_pro_yearly"
    static let lifetimeProductID = "shlf_pro_lifetime"

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs = Set<String>()
    private(set) var isLoadingProducts = false
    private(set) var lastLoadError: String?

    private var productIDs: [String] = [
        StoreKitService.yearlyProductID,
        StoreKitService.monthlyProductID,
        StoreKitService.lifetimeProductID
    ]
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
                let fetched = try await Product.products(for: productIDs)
                products = fetched.sorted { productSortIndex($0.id) < productSortIndex($1.id) }
                if !products.isEmpty {
                    return // Success, exit early
                }
                lastLoadError = "Products unavailable. Check App Store Connect or network."
            } catch {
                #if DEBUG
                print("Failed to load products (attempt \(attempt)/3): \(error)")
                #else
                AppLogger.logError(error, context: "StoreKit load products attempt \(attempt)", logger: AppLogger.network)
                #endif
                lastLoadError = error.localizedDescription

                if attempt < 3 {
                    // Exponential backoff: 1s, 2s
                    let delay = UInt64(attempt * 1_000_000_000) // nanoseconds
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }

        // All retries failed - products will remain empty
        #if DEBUG
        print("All product loading attempts failed")
        #else
        AppLogger.logWarning("All StoreKit product loading attempts failed", logger: AppLogger.network)
        #endif
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

    @MainActor
    func resetLocalProState() {
        purchasedProductIDs.removeAll()
        ProAccess.setCachedIsPro(false)
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
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
                    #if DEBUG
                    print("Transaction verification failed: \(error)")
                    #else
                    AppLogger.logError(error, context: "Transaction verification", logger: AppLogger.network)
                    #endif
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
                #if DEBUG
                print("Failed to verify transaction: \(error)")
                #else
                AppLogger.logError(error, context: "Transaction verify", logger: AppLogger.network)
                #endif
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

    private func productSortIndex(_ id: String) -> Int {
        productIDs.firstIndex(of: id) ?? Int.max
    }
}
