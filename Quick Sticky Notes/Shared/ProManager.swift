import Foundation
import StoreKit

@MainActor
class ProManager: ObservableObject {
    static let shared = ProManager()
    
    @Published private(set) var isProUser = false
    @Published private(set) var products: [Product] = []
    @Published var purchaseError: String?
    
    private let defaults = UserDefaults.standard
    private let proStatusKey = "is_pro_purchased"
    
    private init() {
        loadProStatus()
        
        // Load products when initialized
        Task {
            await loadProducts()
            await updatePurchaseStatus()
        }
        
        // Listen for transaction updates
        Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    // Handle successful transaction
                    await handleVerifiedTransaction(transaction)
                }
            }
        }
    }
    
    private func loadProducts() async {
        do {
            print("ProManager: Starting to load products...")
            let productIdentifiers = ["com.qsnotes.pro.lifetime"]
            print("ProManager: Requesting products with IDs: \(productIdentifiers)")
            products = try await Product.products(for: productIdentifiers)
            print("ProManager: Successfully loaded \(products.count) products:")
            for product in products {
                print("ProManager: - Product: \(product.id), Type: \(product.type), Price: \(product.displayPrice)")
            }
        } catch {
            print("ProManager: Failed to load products: \(error)")
        }
    }
    
    private func updatePurchaseStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                // Found a valid transaction
                defaults.set(true, forKey: proStatusKey)
                isProUser = true
                return
            }
        }
        
        // No valid transactions found
        defaults.set(false, forKey: proStatusKey)
        isProUser = false
    }
    
    var canAccessProFeatures: Bool {
        isProUser
    }
    
    // MARK: - Shortcut Usage Tracking
    
    func trackShortcutUsage() -> Bool {
        // Pro users don't need tracking
        if isProUser {
            return false
        }
        
        // Get current count
        let currentCount = defaults.integer(forKey: "shortcut_usage_count")
        let newCount = currentCount + 1
        
        // Save the new count
        defaults.set(newCount, forKey: "shortcut_usage_count")
        
        // Determine if we should show the upgrade prompt
        let shouldNag = (newCount % 20 == 0) // Show upgrade prompt every 20 uses
        return shouldNag
    }
    
    private func loadProStatus() {
        isProUser = defaults.bool(forKey: proStatusKey)
    }
    
    // MARK: - Purchase Handling
    func purchasePro(product: Product? = nil) async {
        do {
            guard let productToPurchase = product ?? products.first else {
                purchaseError = "No products available"
                return
            }
            
            let result = try await productToPurchase.purchase()
            
            switch result {
            case .success(let verification):
                // Check if the transaction is verified
                switch verification {
                case .verified(let transaction):
                    // Successful purchase
                    defaults.set(true, forKey: proStatusKey)
                    isProUser = true
                    
                    // Finish the transaction
                    await transaction.finish()
                    
                case .unverified(_, let error):
                    // Failed verification
                    purchaseError = "Purchase verification failed: \(error)"
                }
                
            case .userCancelled:
                purchaseError = "Purchase cancelled"
                
            case .pending:
                purchaseError = "Purchase pending"
                
            @unknown default:
                purchaseError = "Unknown purchase result"
            }
            
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }
    }
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchaseStatus()
            
            if !isProUser {
                purchaseError = "No purchases to restore"
            }
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Development Testing
    #if DEBUG
    func resetAllPurchases() {
        defaults.removeObject(forKey: proStatusKey)
        isProUser = false
    }
    
    func toggleProStatus() {
        isProUser.toggle()
        defaults.set(isProUser, forKey: proStatusKey)
    }
    #endif
    
    private func handleVerifiedTransaction(_ transaction: Transaction) async {
        // A purchase or restored purchase has been verified
        defaults.set(true, forKey: proStatusKey)
        isProUser = true
        
        // Always finish a transaction
        await transaction.finish()
    }
} 