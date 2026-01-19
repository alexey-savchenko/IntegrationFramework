import Combine
import Foundation

public final class IntegrationFramework: @unchecked Sendable {
    private init() {}
    
    public static let shared = IntegrationFramework()
    
    private let configService = ConfigService.shared
    private let analyticsService = AnalyticsService.shared
    private let purchaseService = PurchaseService.shared
    
    public var baseURL = ""
    public var path = ""
    public var purchasesKey = ""
}

extension IntegrationFramework: ConfigServiceProtocol {
    public func fetchConfig(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        assert(baseURL != "" && path != "")
        configService.fetchConfig(completion: completion)
    }
    public func getConfig() -> ConfigResponse? {
        assert(baseURL != "" && path != "")
        return configService.getConfig()
    }
}

extension IntegrationFramework: AnalyticsServiceProtocol {
    public func log(event: Event) {
        assert(baseURL != "" && path != "")
        analyticsService.log(event: event)
    }
}

extension IntegrationFramework: PurchaseServiceProtocol {
    public var isSubscribed: Bool {
        assert(purchasesKey != "")
        return purchaseService.isSubscribed
    }
    
    public var isSubscribedSubject: AnyPublisher<Bool, Never> {
        assert(purchasesKey != "")
        return purchaseService.isSubscribedSubject
    }
    
    public func start(completion: @escaping @Sendable () -> Void) {
        assert(purchasesKey != "")
        purchaseService.start(completion: completion)
    }
    
    public func restore(completion: @escaping @Sendable (Bool) -> Void) {
        assert(purchasesKey != "")
        purchaseService.restore(completion: completion)
    }
    
    public func purchase<IAP>(
        _ iap: IAP,
        cancelled: @escaping @Sendable () -> Void,
        completion: @escaping @Sendable (Result<Bool, any Error>) -> Void
    ) where IAP : RawRepresentable, IAP.RawValue == String {
        assert(purchasesKey != "")
        purchaseService.purchase(iap, cancelled: cancelled, completion: completion)
    }
}
