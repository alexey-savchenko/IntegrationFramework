import UIKit
import WebKit

/// Service for managing Silent RSOC (Remote Sponsored Offer Content) integration.
///
/// `RSOCService` provides a high-level API for integrating RSOC into your app's
/// onboarding and paywall flow. It handles WebView preloading, flow coordination,
/// and sponsor page display.
///
/// ## Usage
/// ```swift
/// // 1. Configure sponsor view appearance (optional)
/// RSOCService.shared.sponsorViewConfig = RSOCSponsorViewConfig(
///     backgroundColor: .systemBackground,
///     titleColor: .label
/// )
///
/// // 2. Preload RSOC during app startup
/// await RSOCService.shared.preloadIfNeeded(
///     shouldPreload: !hasCompletedOnboarding
/// )
///
/// // 3. Create flow coordinator for onboarding
/// let coordinator = RSOCService.shared.createFlowCoordinator(
///     onboarding: myOnboarding,
///     paywallProvider: { MyPaywall() },
///     onOnboardingComplete: {
///         UserDefaults.standard.set(true, forKey: "onboardingCompleted")
///     }
/// )
/// coordinator.completion = { self.showMainScreen() }
/// window?.rootViewController = coordinator
/// ```
public final class RSOCService: @unchecked Sendable {
    
    /// Shared singleton instance.
    public static let shared = RSOCService()
    
    /// Configuration for the sponsor view appearance.
    ///
    /// Set this before creating the flow coordinator to customize the sponsor page.
    public var sponsorViewConfig = RSOCSponsorViewConfig.default
    
    private var rsocManager: SilentRSOCManager { SilentRSOCManager.shared }
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Whether RSOC is enabled in the remote configuration.
    public var isEnabled: Bool {
        rsocManager.isEnabled
    }
    
    /// Whether RSOC is preloaded and ready.
    public var isReady: Bool {
        rsocManager.isReady
    }
    
    // MARK: - Preloading
    
    /// Preloads the RSOC WebView.
    ///
    /// Call this during app startup (e.g., on splash screen) to preload the RSOC content.
    /// The WebView is loaded invisibly in the background.
    ///
    /// - Parameter completion: Called with `true` if preload succeeded, `false` otherwise.
    public func preload(completion: (@Sendable (Bool) -> Void)? = nil) {
        rsocManager.preload(completion: completion)
    }
    
    /// Preloads RSOC if conditions are met.
    ///
    /// Use this async method for cleaner integration with Swift concurrency.
    ///
    /// - Parameter shouldPreload: Whether preloading should occur (e.g., onboarding not completed).
    /// - Returns: `true` if preload succeeded or was skipped, `false` if preload failed.
    @MainActor
    public func preloadIfNeeded(shouldPreload: Bool) async -> Bool {
        guard shouldPreload else { return true }
        guard isEnabled else { return true }
        
        return await withCheckedContinuation { continuation in
            preload { success in
                print(success ? "✅ RSOC preloaded" : "⚠️ RSOC preload failed")
                continuation.resume(returning: success)
            }
        }
    }
    
    // MARK: - Flow Coordinator
    
    /// Creates an RSOC flow coordinator for onboarding with paywall.
    ///
    /// The coordinator manages the complete RSOC flow:
    /// 1. Displays onboarding with RSOC WebView overlay
    /// 2. Handles user interactions and screen transitions
    /// 3. Presents paywall after onboarding
    /// 4. Shows sponsor page after paywall (if configured)
    ///
    /// - Parameters:
    ///   - onboarding: The onboarding view controller. Must conform to `RSOCOnboardingProtocol`.
    ///   - paywallProvider: A closure that creates a new paywall instance. Must conform to `RSOCPaywallProtocol`.
    ///   - onOnboardingComplete: Called when onboarding completes, before paywall is shown.
    ///     Use this to save completion flags.
    /// - Returns: A view controller to use as the root view controller.
    ///
    /// - Note: Set `completion` on the returned coordinator to handle flow completion.
    public func createFlowCoordinator(
        onboarding: RSOCOnboardingProtocol,
        paywallProvider: @escaping @Sendable () -> RSOCPaywallProtocol,
        onOnboardingComplete: (@Sendable () -> Void)? = nil
    ) -> RSOCFlowCoordinator {
        return RSOCFlowCoordinator(
            onboarding: onboarding,
            paywallProvider: paywallProvider,
            onOnboardingComplete: onOnboardingComplete,
            sponsorViewConfig: sponsorViewConfig
        )
    }
    
    // MARK: - Sponsor View
    
    /// Creates a sponsor view with the current configuration.
    ///
    /// Use this if you need to display the sponsor view manually
    /// (e.g., in a custom paywall implementation).
    ///
    /// - Returns: A configured sponsor view.
    public func createSponsorView() -> RSOCSponsorView {
        return RSOCSponsorView(config: sponsorViewConfig)
    }
    
    // MARK: - Cleanup
    
    /// Cleans up RSOC resources.
    ///
    /// Call this when the RSOC flow is complete or if you need to reset the state.
    public func cleanup() {
        rsocManager.cleanup()
    }
}
