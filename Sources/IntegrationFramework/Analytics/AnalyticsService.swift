import Foundation

/// Analytics events that can be tracked.
///
/// Each event corresponds to a specific user action or screen view
/// and is sent to a tracking URL defined in the remote configuration.
public enum Event: Sendable {
    /// User viewed an onboarding screen.
    /// - Parameter Int: The screen number (e.g., 1, 2, 3).
    case onboardingView(Int)
    
    /// User viewed the paywall screen.
    case paywallView
    
    /// Conversion event (e.g., completed purchase).
    case conversion
    
    /// User clicked the paywall CTA (Call To Action) button.
    case paywallCTAClick
    
    /// User clicked the paywall close button.
    case paywallCloseClick
    
    /// User closed the payment popup.
    case paywallPopUpCloseClick
    
    /// Silent RSOC sponsored page became visible.
    case silentRsocSponsoredPageVisible
    
    /// User viewed silent RSOC screen 1.
    case silentRsocScreen1View
    
    /// User viewed silent RSOC screen 2.
    case silentRsocScreen2View
    
    /// Silent RSOC sponsored page loaded.
    case silentRsocSponsoredPageLoad
}

/// Protocol defining analytics service interface.
public protocol AnalyticsServiceProtocol {
    /// Logs an analytics event.
    ///
    /// - Parameter event: The event to log.
    func log(event: Event)
}

/// Service for tracking and logging analytics events.
///
/// `AnalyticsService` sends analytics events to tracking URLs defined
/// in the remote configuration. Each event type maps to a specific
/// tracking endpoint.
///
/// - Note: Events are sent as fire-and-forget GET requests.
///   No completion handlers or error handling is provided.
final class AnalyticsService: AnalyticsServiceProtocol, @unchecked Sendable {

    private init() {}
    
    /// Shared singleton instance.
    static let shared = AnalyticsService()
    
    /// Logs an analytics event to the configured tracking endpoint.
    ///
    /// This method maps the event to its corresponding tracking URL from the
    /// remote configuration, then sends a GET request to that URL.
    ///
    /// - Parameter event: The event to log.
    ///
    /// - Note: This is a fire-and-forget operation. No completion handler is provided.
    /// - Important: Requires configuration to be fetched first via `fetchConfig(completion:)`.
    ///   If no configuration is available, the event is silently ignored.
    func log(event: Event) {
        guard let config = IntegrationFramework.shared.getConfig() else { return }
        
        var url = URL(string: "")
        
        switch event {
        case .silentRsocScreen1View:
            url = config.silentRsocScreen1View.flatMap(URL.init(string:))
        case .silentRsocScreen2View:
            url = config.silentRsocScreen2View.flatMap(URL.init(string:))
        case .silentRsocSponsoredPageLoad:
            url = config.silentRsocSponsoredPageLoad.flatMap(URL.init(string:))
        case .silentRsocSponsoredPageVisible:
            url = config.silentRsocSponsoredPageVisible.flatMap(URL.init(string:))
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
