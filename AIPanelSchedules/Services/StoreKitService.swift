//
//  StoreKitService.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/19/25.
//

import StoreKit
import Foundation
import Combine

@MainActor
class StoreKitService: ObservableObject {
    enum PurchaseVerificationError: Error {
        case failedVerification
    }
    @Published var products: [Product] = []
    @Published var pricedProducts: [CreditProduct] = []
    @Published var lastPurchasedProductID: String?
    
    @Published var isRestoring: Bool = false
    @Published var restoreMessage: String? = nil
    
    struct PurchaseEvent: Identifiable {
        let id: UInt64              // transaction.id
        let productID: String
    }

    @Published var purchaseEvent: PurchaseEvent?
    private var deliveredTransactionIDs = Set<UInt64>()
    private var updatesTask: Task<Void, Never>?
    init() {
        startListeningForTransactions()
    }

    deinit {
        updatesTask?.cancel()
    }
    private let baseCreditProducts: [CreditProduct] = [
        CreditProduct(
            id: "com.aipanelschedules.credits_1",
            credits: 1,
            title: "1 Credit",
            subtitle: "Unlocks 1 Excel file",
            priceText: "—"
        ),
        CreditProduct(
            id: "com.aipanelschedules.credits_3",
            credits: 3,
            title: "3 Credits",
            subtitle: "Unlocks 3 Excel files",
            priceText: "—"
        ),
        CreditProduct(
            id: "com.aipanelschedules.credits_10",
            credits: 10,
            title: "10 Credits",
            subtitle: "Unlocks 10 Excel files",
            priceText: "—"
        )
    ]
    private func startListeningForTransactions() {
        updatesTask?.cancel()
        updatesTask = Task(priority: .background) { [weak self] in
            guard let self else { return }

            for await result in Transaction.updates {
                do {
                    let transaction: Transaction = try self.checkVerified(result)

                    print("🧾 Transaction update:", transaction.productID)

                    await MainActor.run {
                        self.lastPurchasedProductID = transaction.productID
                        self.emitPurchaseEventIfNeeded(transaction)
                    }

                    await transaction.finish()

                } catch {
                    print("❌ Transaction verification failed:", error)
                }
            }
        }
    }
    private func emitPurchaseEventIfNeeded(_ transaction: Transaction) {
        // prevent duplicate credit grants
        guard !deliveredTransactionIDs.contains(transaction.id) else { return }
        deliveredTransactionIDs.insert(transaction.id)

        self.purchaseEvent = PurchaseEvent(id: transaction.id, productID: transaction.productID)
    }
    @MainActor
    func loadProducts() async {
        let productIDs: Set<String> = [
            "com.aipanelschedules.credits_1",
            "com.aipanelschedules.credits_3",
            "com.aipanelschedules.credits_10"
        ]

        print("🛒 Requested product IDs:", productIDs)
        do {
            let products = try await Product.products(for: productIDs)

            print("🛒 Products returned:", products.map { $0.id })

            self.products = products
            // 🔗 Map StoreKit prices into UI models
            self.pricedProducts = self.baseCreditProducts.map { base in
                var updated = base

                if let skProduct = products.first(where: { $0.id == base.id }) {
                    updated.priceText = skProduct.displayPrice
                }

                return updated
            }
            print("🛒 Loaded StoreKit products:", products)

        } catch {
            print("❌ StoreKit error:", error)
        }
    }
    
    @MainActor
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction: Transaction = try self.checkVerified(verification)

                print("🧾 Purchase success:", transaction.productID)

                self.lastPurchasedProductID = transaction.productID
           //     self.emitPurchaseEventIfNeeded(transaction)
                await transaction.finish()

                return true

            case .userCancelled:
                print("⚠️ User cancelled purchase")
                return false

            case .pending:
                print("⏳ Purchase pending approval")
                return false

            @unknown default:
                return false
            }
        } catch {
            print("❌ Purchase failed:", error)
            return false
        }
    }
    @MainActor
    func restorePurchases() async {
        isRestoring = true
        restoreMessage = nil
        defer { isRestoring = false }

        do {
            print("🔄 Restore: starting AppStore.sync()")
            try await AppStore.sync()
            print("✅ Restore: AppStore.sync() finished")

            restoreMessage = "Restore complete. If you previously purchased credits, they’ll appear shortly."
        } catch {
            print("❌ Restore: AppStore.sync() failed:", error)
            restoreMessage = "Restore failed: \(error.localizedDescription)"
        }
    }
    func creditsForProductID(_ productID: String) -> Int {
        switch productID {
        case "com.aipanelschedules.credits_1": return 1
        case "com.aipanelschedules.credits_3": return 3
        case "com.aipanelschedules.credits_10": return 10
        default: return 0
        }
    }
    private func checkVerified<T>(
        _ result: VerificationResult<T>
    ) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw PurchaseVerificationError.failedVerification
        }
    }
}
    
