import StoreKit
import SwiftUI

public enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case trial = "Free Trial + Annual"
    case monthly = "Monthly"
    
    public var id: String { rawValue }
    
    var productId: String {
        switch self {
        case .monthly:
            return "com.yearsync.monthly"
        case .trial:
            return "com.yearsync.annual.trial"
        }
    }
}

@MainActor
public class StoreKitManager: ObservableObject {
    public static let shared = StoreKitManager()
    
    @Published public private(set) var subscriptionProducts: [Product] = []
    @Published public private(set) var purchasedSubscriptions: [Product] = []
    @Published public private(set) var isSubscribed = false
    @Published public var isPurchasing = false
    @Published public private(set) var lastPurchaseError: String?
    
    private let productIdentifiers = [
        "com.yearsync.monthly",
        "com.yearsync.annual.trial"
    ]
    
    private var updateListenerTask: Task<Void, Error>?
    
    public init() {
        print("StoreKitManager: Initializing...")
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreKit.Transaction.updates {
                await self.handle(updatedTransaction: result)
            }
        }
    }
    
    private func loadProducts() async {
        do {
            print("StoreKitManager: Starting to load products...")
            print("StoreKitManager: Product identifiers:", productIdentifiers)
            
            // Verify we're in the correct environment
            if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL {
                print("StoreKitManager: Receipt URL environment: \(appStoreReceiptURL.path)")
            }
            
            subscriptionProducts = try await Product.products(for: productIdentifiers)
            
            print("StoreKitManager: Successfully loaded \(subscriptionProducts.count) products:")
            for product in subscriptionProducts {
                print("- Product ID: \(product.id)")
                print("  Display Name: \(product.displayName)")
                print("  Description: \(product.description)")
                print("  Price: \(product.price)")
                
                // Check subscription status
                if let status = try? await product.subscription?.status {
                    print("  Subscription Status: \(status)")
                }
            }
            
            if subscriptionProducts.isEmpty {
                print("StoreKitManager WARNING: No products were loaded!")
                self.lastPurchaseError = "No products available"
            }
        } catch {
            print("StoreKitManager ERROR: Failed to load products:", error)
            self.lastPurchaseError = "Failed to load products: \(error.localizedDescription)"
        }
    }
    
    public func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isPurchasing = true
        lastPurchaseError = nil
        
        defer { 
            isPurchasing = false
        }
        
        // Verify app store environment
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            print("StoreKitManager ERROR: No receipt URL found")
            throw StoreError.noReceipt
        }
        print("StoreKitManager: Purchase attempt in environment: \(receiptURL.path)")
        
        // Check for active account first
        if #available(iOS 15.0, *) {
            do {
                let verificationResult = try await AppTransaction.shared
                let appTransaction = try checkVerified(verificationResult)
                print("StoreKitManager: Active account found with original app version: \(appTransaction.originalAppVersion)")
            } catch {
                print("StoreKitManager ERROR: No active account detected during purchase")
                self.lastPurchaseError = "No active App Store account"
                throw StoreError.noActiveAccount
            }
        }
        
        if !subscriptionProducts.contains(where: { $0.id == product.id }) {
            print("StoreKitManager ERROR: Product not found in loaded products. Available products:", subscriptionProducts.map { $0.id })
            self.lastPurchaseError = "Product not available"
            throw StoreError.noProduct
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                do {
                    let transaction = try checkVerified(verification)
                    print("StoreKitManager: Purchase successful for product: \(product.id)")
                    await transaction.finish()
                    await updateSubscriptionStatus()
                    return transaction
                } catch {
                    print("StoreKitManager ERROR: Transaction verification failed: \(error)")
                    self.lastPurchaseError = "Purchase verification failed"
                    throw StoreError.failedVerification
                }
                
            case .userCancelled:
                print("StoreKitManager: Purchase cancelled by user")
                self.lastPurchaseError = "Purchase cancelled"
                return nil
                
            case .pending:
                print("StoreKitManager: Purchase is pending further action")
                self.lastPurchaseError = "Purchase pending approval"
                throw StoreError.purchasePending
                
            @unknown default:
                print("StoreKitManager ERROR: Unknown purchase result")
                self.lastPurchaseError = "Unknown purchase error"
                throw StoreError.purchaseFailed
            }
        } catch let error as StoreError {
            self.lastPurchaseError = error.localizedDescription
            throw error
        } catch {
            print("StoreKitManager ERROR: Purchase failed with error: \(error.localizedDescription)")
            self.lastPurchaseError = "Purchase failed: \(error.localizedDescription)"
            throw StoreError.purchaseFailed
        }
    }
    
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            print("StoreKitManager ERROR: Verification failed: \(error)")
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    private func handle(updatedTransaction: VerificationResult<StoreKit.Transaction>) async {
        do {
            let transaction = try checkVerified(updatedTransaction)
            print("StoreKitManager: Handling verified transaction: \(transaction.productID)")
            await updateSubscriptionStatus()
            await transaction.finish()
        } catch {
            print("StoreKitManager ERROR: Transaction failed verification")
        }
    }
    
    func updateSubscriptionStatus() async {
        var purchasedSubscriptions: [Product] = []
        
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if let subscription = subscriptionProducts.first(where: { $0.id == transaction.productID }) {
                    purchasedSubscriptions.append(subscription)
                    print("StoreKitManager: Found active subscription for product: \(transaction.productID)")
                }
            } catch {
                print("StoreKitManager ERROR: Failed to verify transaction:", error)
            }
        }
        
        self.purchasedSubscriptions = purchasedSubscriptions
        self.isSubscribed = !purchasedSubscriptions.isEmpty
        print("StoreKitManager: Subscription status updated - isSubscribed: \(isSubscribed)")
    }
    
    public func product(for plan: SubscriptionPlan) -> Product? {
        let product = subscriptionProducts.first { $0.id == plan.productId }
        print("StoreKitManager: Looking for product with ID:", plan.productId)
        print("StoreKitManager: Found product:", product?.id ?? "nil")
        return product
    }
}

enum StoreError: LocalizedError {
    case failedVerification
    case noProduct
    case purchaseFailed
    case subscriptionExpired
    case purchasePending
    case noActiveAccount
    case noReceipt
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Failed to verify the purchase."
        case .noProduct:
            return "The selected subscription product is not available."
        case .purchaseFailed:
            return "The purchase could not be completed."
        case .subscriptionExpired:
            return "Your subscription has expired."
        case .purchasePending:
            return "The purchase is pending. Please check your payment method or parental controls."
        case .noActiveAccount:
            return "No App Store account found. Please sign in with a Sandbox Tester account in Settings > App Store."
        case .noReceipt:
            return "No App Store receipt found. Please ensure you're signed in to the App Store."
        }
    }
} 