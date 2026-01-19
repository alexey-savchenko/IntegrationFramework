import Foundation

public struct ConfigResponse: Codable, Sendable {
    public let status: String
    public let paywall: String
    public let onboarding: String
    public let conversion: String
    public let view: String
    public let viewNumber: String
    public let setId: String?
    public let localization: Localization
    public let paywallCtaClick: String?
    public let paywallCrossClick: String?
    public let paymentPopupCrossClick: String?
    public let specialOfferView: String?
    public let specialOfferCtaClick: String?
    public let specialOfferCrossClick: String?
    public let silentRsocScreen1View: String?
    public let silentRsocScreen2View: String?
    public let silentRsocSponsoredPageLoad: String?
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
    
    public struct Localization: Codable, Sendable {
        public let version: Version
        public let paywallCrossDelay: Int?
        public let silentRsocConfig: SilentRSOCConfig?
        
        enum CodingKeys: String, CodingKey {
            case version
            case paywallCrossDelay
            case silentRsocConfig = "silent_rsoc_config"
        }
        
        public struct Version: Codable, Sendable {
            public let latestVersion: String
        }
        
        public struct SilentRSOCConfig: Codable, Sendable {
            public let isEnabled: Bool
            public let isSponsorPageVisible: Bool
            public let link: String
            
            enum CodingKeys: String, CodingKey {
                case isEnabled = "is_enabled"
                case isSponsorPageVisible = "is_sponsor_page_visible"
                case link
            }
        }
    }
}
