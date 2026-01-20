import SnapKit
import UIKit
import WebKit

/// A view that displays sponsored content with a countdown timer.
///
/// This view is shown after the paywall closes when RSOC sponsor page is enabled.
/// It displays a WebView with the sponsor content and a countdown timer.
///
/// ## Usage
/// ```swift
/// let sponsorView = RSOCSponsorView(config: RSOCService.shared.sponsorViewConfig)
/// sponsorView.onCountdownFinished = { [weak self] in
///     self?.dismissSponsorPage()
/// }
/// sponsorView.embedWebView(webView)
/// sponsorView.startCountdown()
/// ```

public final class RSOCSponsorView: UIView, @unchecked Sendable {
    /// Called when the countdown timer reaches zero.
    public var onCountdownFinished: (() -> Void)?
    
    private let config: RSOCSponsorViewConfig
    nonisolated(unsafe) private var timer: Timer?
    private var remainingSeconds: Int
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = config.titleText
        label.textColor = config.titleColor
        label.font = config.titleFont
        return label
    }()
    
    private lazy var countdownLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = config.titleColor
        label.font = config.countdownFont
        return label
    }()
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = config.containerBackgroundColor
        view.layer.cornerRadius = config.containerCornerRadius
        view.clipsToBounds = true
        return view
    }()
    
    /// Creates a new sponsor view with the specified configuration.
    ///
    /// - Parameter config: The visual configuration for the sponsor view.
    public init(config: RSOCSponsorViewConfig = .default) {
        self.config = config
        self.remainingSeconds = config.countdownDuration
        super.init(frame: .zero)
        
        setupUI()
        updateCountdownLabel()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        timer?.invalidate()
    }
    
    /// Starts the countdown timer.
    ///
    /// Call this after embedding the WebView and adding the view to the hierarchy.
    public func startCountdown() {
        timer?.invalidate()
        remainingSeconds = config.countdownDuration
        updateCountdownLabel()
        
        let newTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }
    
    /// Embeds a WebView into the sponsor view container.
    ///
    /// - Parameter webView: The WebView to display as sponsor content.
    public func embedWebView(_ webView: WKWebView) {
        containerView.subviews.forEach { $0.removeFromSuperview() }
        containerView.addSubview(webView)
        webView.alpha = 1
        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Remove the invisibility style that was added during RSOC flow
        let script = """
            var style = document.getElementById('rsoc-invisible');
            if (style) { style.remove(); }
            """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
    
    private func tick() {
        remainingSeconds -= 1
        updateCountdownLabel()
        
        if remainingSeconds <= 0 {
            timer?.invalidate()
            timer = nil
            countdownLabel.isHidden = true
            onCountdownFinished?()
        }
    }
    
    private func updateCountdownLabel() {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        countdownLabel.text = String(format: config.countdownFormat, minutes, seconds)
    }
    
    private func setupUI() {
        backgroundColor = config.backgroundColor
        
        addSubview(titleLabel)
        addSubview(countdownLabel)
        addSubview(containerView)
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide).offset(16)
            make.horizontalEdges.equalToSuperview().inset(16)
        }
        
        countdownLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
        }
        
        containerView.snp.makeConstraints { make in
            make.top.equalTo(countdownLabel.snp.bottom).offset(16)
            make.horizontalEdges.equalToSuperview().inset(16)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-16)
        }
    }
}
