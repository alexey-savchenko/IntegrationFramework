import UIKit
import WebKit

/// Protocol for onboardings that support Silent RSOC overlay.
///
/// Implement this protocol in your onboarding view controller to enable
/// RSOC WebView overlay alignment and step advancement.
///
/// ## Usage
/// ```swift
/// class MyOnboarding: UIViewController, RSOCOnboardingProtocol {
///     var completion: (() -> Void)?
///     var currentOnboardingStep: Int = 0
///
///     func getContinueButtonFrame() -> CGRect {
///         continueButton.convert(continueButton.bounds, to: view)
///     }
///
///     func advanceStep() {
///         currentOnboardingStep += 1
///         updateUI()
///     }
/// }
/// ```
public protocol RSOCOnboardingProtocol: UIViewController {
    /// Closure called when onboarding is complete.
    var completion: (() -> Void)? { get set }
    
    /// Returns the Continue button's frame in the view's coordinate system.
    ///
    /// This is used to align the RSOC WebView clickable element
    /// with the onboarding's continue button.
    func getContinueButtonFrame() -> CGRect
    
    /// Advances to the next onboarding step.
    ///
    /// Called by the RSOC flow when user interaction is detected.
    func advanceStep()
    
    /// Current onboarding step (0-based).
    var currentOnboardingStep: Int { get }
}

/// Protocol for paywalls that support RSOC sponsor page display.
///
/// Implement this protocol in your paywall view controller to enable
/// sponsor page display after paywall close.
///
/// ## Usage
/// ```swift
/// class MyPaywall: UIViewController, RSOCPaywallProtocol {
///     var closeAction: (() -> Void)?
///     var rsocSponsorWebView: WKWebView?
///     var isSponsorPageVisible: Bool = false
/// }
/// ```
public protocol RSOCPaywallProtocol: UIViewController {
    /// Closure called when paywall should close.
    var closeAction: (() -> Void)? { get set }
    
    /// The RSOC sponsor WebView to display after paywall closes.
    ///
    /// Set by the RSOC flow coordinator before presenting the paywall.
    var rsocSponsorWebView: WKWebView? { get set }
    
    /// Whether the sponsor page should be visible after paywall closes.
    ///
    /// When `true`, the paywall should show the sponsor page with countdown
    /// instead of immediately closing.
    var isSponsorPageVisible: Bool { get set }
}
