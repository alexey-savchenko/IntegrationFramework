import Foundation

public enum Event: Sendable {
    case onboardingView(Int)
    case paywallView
    case conversion
    case paywallCTAClick
    case paywallCloseClick
    case paywallPopUpCloseClick
}

public protocol AnalyticsServiceProtocol {
    func log(event: Event)
}

final class AnalyticsService: AnalyticsServiceProtocol {

    private init() {}
    
    nonisolated(unsafe) public static let shared = AnalyticsService()
    
    func log(event: Event) {
        guard let config = IntegrationFramework.shared.getConfig() else { return }
        
        var url = URL(string: "")
        
        switch event {
        case .paywallPopUpCloseClick:
            url = config.paymentPopupCrossClick.flatMap(URL.init(string:))
        case .paywallCloseClick:
            url = config.paywallCrossClick.flatMap(URL.init(string:))
        case .paywallCTAClick:
            url = config.paywallCtaClick.flatMap(URL.init(string:))
        case .conversion:
            url = URL(string: config.conversion)
        case .paywallView:
            url = URL(string: config.view)
        case .onboardingView(let i):
            url = URL(string: config.viewNumber + "\(i)")
        }
        
        if let url {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            URLSession.shared.dataTask(with: request).resume()
        }
    }
}
