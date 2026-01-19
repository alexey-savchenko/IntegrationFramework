import Foundation
import RevenueCat
import Combine

/// Protocol defining purchase service interface.
///
/// Provides methods for managing in-app purchases and subscriptions
/// via RevenueCat.
public protocol PurchaseServiceProtocol: Sendable {
    /// Current subscription status.
    var isSubscribed: Bool { get }
    
    /// Publisher that emits subscription status changes.
    var isSubscribedSubject: AnyPublisher<Bool, Never> { get }
    
    /// Initializes the RevenueCat SDK.
    ///
    /// - Parameter completion: Closure called when initialization completes.
    func start(completion: @escaping (@Sendable () -> Void))
    
    /// Restores previously purchased products.
    ///
    /// - Parameter completion: Closure called with subscription status after restoration.
    func restore(completion: @escaping (@Sendable (Bool) -> Void))
    
    /// Initiates a purchase for the specified product.
    ///
    /// - Parameters:
    ///   - iap: The in-app purchase product identifier.
    ///   - cancelled: Closure called if purchase is cancelled.
    ///   - completion: Closure called with purchase result.
    func purchase<IAP: RawRepresentable>(
        _ iap: IAP,
        cancelled: @escaping @Sendable () -> Void,
        completion: @escaping @Sendable (Result<Bool, Error>) -> Void
    ) where IAP.RawValue == String
}

/// Service for managing in-app purchases and subscriptions.
///
/// `PurchaseService` integrates with RevenueCat to handle:
/// - Product fetching
/// - Purchase processing
/// - Subscription status tracking
/// - Purchase restoration
///
/// ## Usage
/// ```swift
/// // Initialize the service
/// PurchaseService.shared.start {
///     print("Ready for purchases")
/// }
///
/// // Check subscription status
/// if PurchaseService.shared.isSubscribed {
///     print("User is subscribed")
/// }
/// ```
///
/// - Note: This class uses `@unchecked Sendable` as it manages shared
///   mutable state internally with proper synchronization via RevenueCat.
final class PurchaseService: PurchaseServiceProtocol, @unchecked Sendable {
    /// String indicator for lifetime products.
    private let lifetimeProductIndicator = "lifetime"
    
    /// Available products fetched from RevenueCat.
    var products: [Package] = []
    
    /// Current subscription status.
    @Published var isSubscribed: Bool = false
    
    /// Publisher for subscription status changes.
    var isSubscribedSubject: AnyPublisher<Bool, Never> {
        $isSubscribed.eraseToAnyPublisher()
    }
    
    /// Shared singleton instance.
    static let shared = PurchaseService()
    
    private init() {}
    
    /// Initializes the RevenueCat SDK and fetches available products.
    ///
    /// This method:
    /// 1. Configures RevenueCat with the API key from `IntegrationFramework`
    /// 2. Fetches available product offerings
    /// 3. Checks current subscription status (active subscriptions + lifetime purchases)
    /// 4. Starts listening for subscription status changes
    ///
    /// - Parameter completion: Called on the main thread when initialization completes.
    ///
    /// - Important: Must be called before using any purchase functionality.
    ///   Call this early in your app's lifecycle.
    func start(completion: @escaping (@Sendable () -> Void)) {
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .info
        #endif
        Purchases.configure(withAPIKey: IntegrationFramework.shared.purchasesKey)
        
        Purchases.shared.getOfferings { (offerings, error) in
            if let availablePackages = offerings?.current?.availablePackages {
                self.products = availablePackages
            }
            
            Task {
                let info = try? await Purchases.shared.customerInfo()
                let hasActiveSub = !(info?.activeSubscriptions ?? []).isEmpty
                let hasLifetime = info?.nonSubscriptions.first(where: { $0.productIdentifier.contains(self.lifetimeProductIndicator) }) != nil
                
                self.isSubscribed = hasActiveSub || hasLifetime
                await MainActor.run {
                    completion()
                }
            }
            
            Task {
                for try await customerInfo in Purchases.shared.customerInfoStream {
                    let hasActiveSub = !customerInfo.activeSubscriptions.isEmpty
                    
                    let hasLifetime = customerInfo.nonSubscriptions.first(where: { $0.productIdentifier.contains(self.lifetimeProductIndicator) }) != nil
                    
                    self.isSubscribed = hasActiveSub || hasLifetime
                }
            }
        }
    }
    
    /// Restores previously purchased products for the current user.
    ///
    /// Use this to restore purchases on a new device or after reinstalling the app.
    ///
    /// - Parameter completion: Called with `true` if active subscriptions exist,
    ///   `false` otherwise.
    ///
    /// - Note: Also updates the `isSubscribed` property based on the result.
    func restore(completion: @escaping (@Sendable (Bool) -> Void)) {
        Purchases.shared.restorePurchases { customer, error in
            let activeEntitlements = customer?.activeSubscriptions ?? []
            let hasSub = !activeEntitlements.isEmpty
            self.isSubscribed = hasSub
            completion(hasSub)
        }
    }
    
    /// Initiates a purchase for the specified product identifier.
    ///
    /// This method looks up the product in the available offerings and
    /// delegates to the package-based purchase method.
    ///
    /// - Parameters:
    ///   - iap: The product identifier (must have `String` raw value).
    ///   - cancelled: Called if the user cancels the purchase or product not found.
    ///   - completion: Called with purchase result:
    ///     - `.success(true)`: Purchase completed with active entitlements.
    ///     - `.success(false)`: Purchase completed but no entitlements found.
    ///     - `.failure`: An error occurred.
    func purchase<IAP: RawRepresentable>(
        _ iap: IAP,
        cancelled: @escaping @Sendable () -> Void,
        completion: @escaping @Sendable (Result<Bool, Error>) -> Void
    ) where IAP.RawValue == String {
        if let p = products.first(where: { $0.storeProduct.productIdentifier == iap.rawValue }) {
            purchase(product: p, cancelled: cancelled, completion: completion)
        } else {
            cancelled()
        }
    }
    
    /// Initiates a purchase for a specific RevenueCat package.
    ///
    /// This is the internal purchase implementation that handles:
    /// - User cancellation detection and analytics
    /// - Error handling
    /// - Subscription status updates
    ///
    /// - Parameters:
    ///   - product: The RevenueCat package to purchase.
    ///   - cancelled: Called if the user cancels the purchase.
    ///     Also logs `.paywallPopUpCloseClick` event.
    ///   - completion: Called with purchase result:
    ///     - `.success(true)`: Purchase completed with active entitlements.
    ///     - `.success(false)`: Purchase completed but no entitlements found.
    ///     - `.failure`: An error occurred during purchase.
    ///
    /// - Note: Updates `isSubscribed` property on successful purchase.
    func purchase(
        product: Package,
        cancelled: @escaping (@Sendable () -> Void),
        completion: @escaping (@Sendable (Result<Bool, Error>) -> Void)
    ) {
        Purchases.shared.purchase(package: product) { transaction, customerInfo, error, isCanceled in
            if isCanceled {
                IntegrationFramework.shared.log(event: .paywallPopUpCloseClick)
                cancelled()
                return
            }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            let activeSubscriptions = customerInfo?.activeSubscriptions ?? []
            let allPurchasedProductIds = customerInfo?.allPurchasedProductIdentifiers ?? Set()
            let success = !(activeSubscriptions.isEmpty && allPurchasedProductIds.isEmpty)
            self.isSubscribed = success
            completion(.success(success))
        }
    }
}

/// Extension providing convenient accessors for RevenueCat Package properties.
extension Package {
    /// The product identifier (e.g., "com.yourapp.monthly").
    var productId: String {
        self.storeProduct.productIdentifier
    }
    
    /// The localized product name from the App Store.
    var productName: String {
        self.storeProduct.localizedTitle
    }
    
    /// The localized price string (e.g., "$9.99").
    var price: String {
        self.storeProduct.localizedPriceString
    }
}
