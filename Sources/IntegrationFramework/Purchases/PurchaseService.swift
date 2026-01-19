import Foundation
import RevenueCat
import Combine

public protocol PurchaseServiceProtocol: Sendable {
    var isSubscribed: Bool { get }
    var isSubscribedSubject: AnyPublisher<Bool, Never> { get }
    func start(completion: @escaping (@Sendable () -> Void))
    func restore(completion: @escaping (@Sendable (Bool) -> Void))
    func purchase<IAP: RawRepresentable>(
        _ iap: IAP,
        cancelled: @escaping @Sendable () -> Void,
        completion: @escaping @Sendable (Result<Bool, Error>) -> Void
    ) where IAP.RawValue == String
}

final class PurchaseService: PurchaseServiceProtocol, @unchecked Sendable {
    private let lifetimeProductIndicator = "lifetime"
    
    var products: [Package] = []
    
    @Published var isSubscribed: Bool = false
    var isSubscribedSubject: AnyPublisher<Bool, Never> {
        $isSubscribed.eraseToAnyPublisher()
    }
    
    static let shared = PurchaseService()
    private init() {}
    
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
    
    func restore(completion: @escaping (@Sendable (Bool) -> Void)) {
        Purchases.shared.restorePurchases { customer, error in
            let activeEntitlements = customer?.activeSubscriptions ?? []
            let hasSub = !activeEntitlements.isEmpty
            self.isSubscribed = hasSub
            completion(hasSub)
        }
    }
    
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

extension Package {
    var productId: String {
        self.storeProduct.productIdentifier
    }
    
    var productName: String {
        self.storeProduct.localizedTitle
    }
    
    var price: String {
        self.storeProduct.localizedPriceString
    }
}
