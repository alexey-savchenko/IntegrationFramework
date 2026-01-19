import Foundation

/// Application configuration received from the remote server.
///
/// Contains tracking URLs for analytics events, feature flags,
/// and localization settings.
///
/// ## Usage
/// ```swift
/// if let config = IntegrationFramework.shared.getConfig() {
///     print("Paywall URL: \(config.paywall)")
///     print("Latest version: \(config.localization.version.latestVersion)")
/// }
/// ```
public struct ConfigResponse: Codable, Sendable {
    /// Configuration status indicator.
    public let status: String
    
    /// URL for paywall tracking.
    public let paywall: String
    
    /// URL for onboarding tracking.
    public let onboarding: String
    
    /// URL for conversion tracking.
    public let conversion: String
    
    /// URL for view tracking.
    public let view: String
    
    /// Base URL for numbered view tracking (append screen number).
    public let viewNumber: String
    
    /// Optional set identifier.
    public let setId: String?
    
    /// Localization and feature configuration.
    public let localization: Localization
    
    /// URL for paywall CTA click tracking.
    public let paywallCtaClick: String?
    
    /// URL for paywall close button click tracking.
    public let paywallCrossClick: String?
    
    /// URL for payment popup close button click tracking.
    public let paymentPopupCrossClick: String?
    
    /// URL for special offer view tracking.
    public let specialOfferView: String?
    
    /// URL for special offer CTA click tracking.
    public let specialOfferCtaClick: String?
    
    /// URL for special offer close button click tracking.
    public let specialOfferCrossClick: String?
    
    /// URL for silent RSOC screen 1 view tracking.
    public let silentRsocScreen1View: String?
    
    /// URL for silent RSOC screen 2 view tracking.
    public let silentRsocScreen2View: String?
    
    /// URL for silent RSOC sponsored page load tracking.
    public let silentRsocSponsoredPageLoad: String?
    
    /// URL for silent RSOC sponsored page visible tracking.
    public let silentRsocSponsoredPageVisible: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case paywall
        case onboarding
        case conversion
        case view
        case viewNumber = "view_number"
        case setId = "set_id"
        case localization
        case paywallCtaClick = "paywall_cta_click"
        case paywallCrossClick = "paywall_cross_click"
        case paymentPopupCrossClick = "payment_popup_cross_click"
        case specialOfferView = "special_offer_view"
        case specialOfferCtaClick = "special_offer_cta_click"
        case specialOfferCrossClick = "special_offer_cross_click"
        case silentRsocScreen1View = "silent_rsoc_screen_1_view"
        case silentRsocScreen2View = "silent_rsoc_screen_2_view"
        case silentRsocSponsoredPageLoad = "silent_rsoc_sponsored_page_load"
        case silentRsocSponsoredPageVisible = "silent_rsoc_sponsored_page_visible"
    }
    
    /// Localization and feature configuration.
    public struct Localization: Codable, Sendable {
        /// App version information.
        public let version: Version
        
        /// Optional delay (in seconds) before showing paywall close button.
        public let paywallCrossDelay: Int?
        
        /// Optional configuration for silent RSOC feature.
        public let silentRsocConfig: SilentRSOCConfig?
        
        enum CodingKeys: String, CodingKey {
            case version
            case paywallCrossDelay
            case silentRsocConfig = "silent_rsoc_config"
        }
        
        /// App version information.
        public struct Version: Codable, Sendable {
            /// The latest available app version.
            public let latestVersion: String
        }
        
        /// Configuration for silent RSOC (Remote Sponsored Offer Content) feature.
        public struct SilentRSOCConfig: Codable, Sendable {
            /// Whether the silent RSOC feature is enabled.
            public let isEnabled: Bool
            
            /// Whether the sponsor page should be visible.
            public let isSponsorPageVisible: Bool
            
            /// URL link for the sponsored content.
            public let link: String
            
            enum CodingKeys: String, CodingKey {
                case isEnabled = "is_enabled"
                case isSponsorPageVisible = "is_sponsor_page_visible"
                case link
            }
        }
    }
}
