import UIKit

/// Configuration for the RSOC sponsor view appearance.
///
/// Use this struct to customize the colors, fonts, and text displayed
/// in the sponsor countdown view.
///
/// ## Usage
/// ```swift
/// var config = RSOCSponsorViewConfig.default
/// config.backgroundColor = .systemBackground
/// config.titleColor = .label
/// config.titleFont = .boldSystemFont(ofSize: 24)
/// RSOCService.shared.sponsorViewConfig = config
/// ```
public struct RSOCSponsorViewConfig: Sendable {
    /// Background color of the sponsor view.
    public var backgroundColor: UIColor
    
    /// Text color for the title label.
    public var titleColor: UIColor
    
    /// Font for the title label.
    public var titleFont: UIFont
    
    /// Font for the countdown timer label.
    public var countdownFont: UIFont
    
    /// Corner radius for the WebView container.
    public var containerCornerRadius: CGFloat
    
    /// Background color for the WebView container.
    public var containerBackgroundColor: UIColor
    
    /// Title text displayed above the sponsor content.
    public var titleText: String
    
    /// Countdown duration in seconds.
    public var countdownDuration: Int
    
    /// Format string for countdown label. Use %02d:%02d for mm:ss format.
    public var countdownFormat: String
    
    /// Creates a new sponsor view configuration.
    ///
    /// - Parameters:
    ///   - backgroundColor: Background color of the sponsor view.
    ///   - titleColor: Text color for the title label.
    ///   - titleFont: Font for the title label.
    ///   - countdownFont: Font for the countdown timer label.
    ///   - containerCornerRadius: Corner radius for the WebView container.
    ///   - containerBackgroundColor: Background color for the WebView container.
    ///   - titleText: Title text displayed above the sponsor content.
    ///   - countdownDuration: Countdown duration in seconds.
    ///   - countdownFormat: Format string for countdown label.
    public init(
        backgroundColor: UIColor = .black,
        titleColor: UIColor = .white,
        titleFont: UIFont = .boldSystemFont(ofSize: 24),
        countdownFont: UIFont = .boldSystemFont(ofSize: 17),
        containerCornerRadius: CGFloat = 16,
        containerBackgroundColor: UIColor = .darkGray,
        titleText: String = "Browse while you wait",
        countdownDuration: Int = 30,
        countdownFormat: String = "Wait %02d:%02d to continue"
    ) {
        self.backgroundColor = backgroundColor
        self.titleColor = titleColor
        self.titleFont = titleFont
        self.countdownFont = countdownFont
        self.containerCornerRadius = containerCornerRadius
        self.containerBackgroundColor = containerBackgroundColor
        self.titleText = titleText
        self.countdownDuration = countdownDuration
        self.countdownFormat = countdownFormat
    }
    
    /// Default configuration with dark theme styling.
    public static let `default` = RSOCSponsorViewConfig()
}
