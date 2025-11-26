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

    private var productIDs: [String] = ["shlf_pro_lifetime"]
    private var updates: Task<Void, Never>?

    private init() {
        updates = observeTransactionUpdates()
    }

    deinit {
        updates?.cancel()
    }

    // MARK: - Public API

    var isProUser: Bool {
        !purchasedProductIDs.isEmpty
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            print("Failed to load products: \(error)")
        }
    }

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

    func restorePurchases() async {
        await updatePurchasedProducts()
    }

    // MARK: - Private Methods

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
                    await updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }

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
