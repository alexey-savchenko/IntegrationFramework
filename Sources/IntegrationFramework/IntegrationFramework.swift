import Combine
import Foundation

/// The main entry point for IntegrationFramework.
///
/// `IntegrationFramework` provides a unified interface for configuration management,
/// analytics tracking, and in-app purchase handling. It consolidates functionality
/// from ConfigService, AnalyticsService, and PurchaseService into a single API.
///
/// ## Usage
/// ```swift
/// // Configure the framework
/// IntegrationFramework.shared.baseURL = "https://api.example.com"
/// IntegrationFramework.shared.path = "/config"
/// IntegrationFramework.shared.purchasesKey = "your_revenuecat_key"
///
/// // Fetch configuration
/// IntegrationFramework.shared.fetchConfig { result in
///     switch result {
///     case .success:
///         print("Config loaded")
///     case .failure(let error):
///         print("Error: \(error)")
///     }
/// }
/// ```
///
/// - Note: All properties must be configured before using any methods.
/// - Important: This class is thread-safe and can be accessed from any thread.
public final class IntegrationFramework: @unchecked Sendable {
    private init() {}
    
    /// Shared singleton instance of IntegrationFramework.
    public static let shared = IntegrationFramework()
    
    private let configService = ConfigService.shared
    private let analyticsService = AnalyticsService.shared
    private let purchaseService = PurchaseService.shared
    
    /// The base URL for API requests.
    ///
    /// Must be set before calling any configuration or analytics methods.
    /// - Example: `"https://api.example.com"`
    public var baseURL = ""
    
    /// The API path for the configuration endpoint.
    ///
    /// Must be set before calling any configuration or analytics methods.
    /// - Example: `"/config"`
    public var path = ""
    
    /// The RevenueCat API key for in-app purchase management.
    ///
    /// Must be set before calling any purchase-related methods.
    /// - Example: `"appl_xxxxxxxxxxx"`
    public var purchasesKey = ""
}

// MARK: - Configuration Management

extension IntegrationFramework: ConfigServiceProtocol {
    /// Fetches remote configuration from the server.
    ///
    /// The configuration is automatically cached both in memory and on disk.
    /// Completion handler is called on the main thread.
    ///
    /// - Parameter completion: A closure called with the fetch result.
    ///   - `.success`: Configuration was successfully fetched and cached.
    ///   - `.failure`: An error occurred during fetch or parsing.
    ///
    /// - Precondition: `baseURL` and `path` must be set before calling this method.
    ///
    /// - Note: This method is thread-safe and can be called from any thread.
    public func fetchConfig(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        assert(baseURL != "" && path != "")
        configService.fetchConfig(completion: completion)
    }
    
    /// Retrieves the cached configuration.
    ///
    /// This method first checks the in-memory cache for best performance,
    /// then falls back to disk cache if available.
    ///
    /// - Returns: The cached `ConfigResponse` if available, otherwise `nil`.
    ///
    /// - Precondition: `baseURL` and `path` must be set before calling this method.
    ///
    /// - Note: This method is thread-safe and can be called from any thread.
    public func getConfig() -> ConfigResponse? {
        assert(baseURL != "" && path != "")
        return configService.getConfig()
    }
}

// MARK: - Analytics

extension IntegrationFramework: AnalyticsServiceProtocol {
    /// Logs an analytics event to the configured server.
    ///
    /// The event is sent via a GET request to the appropriate tracking URL
    /// based on the event type and configuration.
    ///
    /// - Parameter event: The event to log. See `Event` for available types.
    ///
    /// - Precondition: `baseURL` and `path` must be set before calling this method.
    ///
    /// - Note: This method is fire-and-forget. No completion handler is provided.
    public func log(event: Event) {
        assert(baseURL != "" && path != "")
        analyticsService.log(event: event)
    }
}

// MARK: - In-App Purchases

extension IntegrationFramework: PurchaseServiceProtocol {
    /// Current subscription status.
    ///
    /// Returns `true` if the user has an active subscription or lifetime purchase.
    ///
    /// - Precondition: `purchasesKey` must be set and `start(completion:)` must be called first.
    public var isSubscribed: Bool {
        assert(purchasesKey != "")
        return purchaseService.isSubscribed
    }
    
    /// Publisher that emits subscription status changes.
    ///
    /// Subscribe to this publisher to be notified whenever the user's
    /// subscription status changes (e.g., after purchase or restoration).
    ///
    /// - Returns: A publisher that emits `Bool` values indicating subscription status.
    ///
    /// - Precondition: `purchasesKey` must be set and `start(completion:)` must be called first.
    public var isSubscribedSubject: AnyPublisher<Bool, Never> {
        assert(purchasesKey != "")
        return purchaseService.isSubscribedSubject
    }
    
    /// Initializes the RevenueCat SDK.
    ///
    /// Must be called before using any purchase-related functionality.
    /// This method configures RevenueCat, fetches available products,
    /// and checks the current subscription status.
    ///
    /// - Parameter completion: A closure called on the main thread when initialization completes.
    ///
    /// - Precondition: `purchasesKey` must be set before calling this method.
    ///
    /// - Important: Call this method early in your app's lifecycle, ideally at launch.
    public func start(completion: @escaping @Sendable () -> Void) {
        assert(purchasesKey != "")
        purchaseService.start(completion: completion)
    }
    
    /// Restores previously purchased products.
    ///
    /// Use this method to restore purchases on a new device or after reinstalling.
    ///
    /// - Parameter completion: A closure called with `true` if the user has active subscriptions,
    ///   `false` otherwise.
    ///
    /// - Precondition: `purchasesKey` must be set and `start(completion:)` must be called first.
    public func restore(completion: @escaping @Sendable (Bool) -> Void) {
        assert(purchasesKey != "")
        purchaseService.restore(completion: completion)
    }
    
    /// Initiates a purchase for the specified product.
    ///
    /// - Parameters:
    ///   - iap: The in-app purchase product identifier (e.g., an enum with `String` raw values).
    ///   - cancelled: A closure called if the user cancels the purchase.
    ///   - completion: A closure called with the purchase result:
    ///     - `.success(true)`: Purchase completed successfully.
    ///     - `.success(false)`: Purchase completed but no active entitlements found.
    ///     - `.failure`: An error occurred during purchase.
    ///
    /// - Precondition: `purchasesKey` must be set and `start(completion:)` must be called first.
    ///
    /// - Note: The `cancelled` closure is called when `paywallPopUpCloseClick` is logged.
    public func purchase<IAP>(
        _ iap: IAP,
        cancelled: @escaping @Sendable () -> Void,
        completion: @escaping @Sendable (Result<Bool, any Error>) -> Void
    ) where IAP : RawRepresentable, IAP.RawValue == String {
        assert(purchasesKey != "")
        purchaseService.purchase(iap, cancelled: cancelled, completion: completion)
    }
}
