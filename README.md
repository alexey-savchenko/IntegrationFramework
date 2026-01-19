# IntegrationFramework

A Swift Package that provides configuration management, analytics tracking, and purchase handling for iOS applications.

## Features

- **Configuration Management**: Fetch and cache remote configuration with automatic disk persistence
- **Analytics Service**: Track user events and send analytics data
- **Purchase Management**: RevenueCat integration for in-app purchases and subscriptions
- **Thread-Safe**: Built with Swift 6 concurrency in mind, fully `Sendable` compliant

## Requirements

- iOS 13.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/alexey-savchenko/IntegrationFramework.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File > Add Package Dependencies
2. Enter: `https://github.com/alexey-savchenko/IntegrationFramework.git`

## Configuration

Before using the framework, configure it with your API endpoints and RevenueCat API key:

```swift
import IntegrationFramework

// Configure base URL and path for config API
IntegrationFramework.shared.baseURL = "https://api.example.com"
IntegrationFramework.shared.path = "/config"
IntegrationFramework.shared.purchasesKey = "your_revenuecat_api_key"
```

## Usage

### Fetching Configuration

```swift
IntegrationFramework.shared.fetchConfig { result in
    switch result {
    case .success:
        print("Config fetched successfully")
        if let config = IntegrationFramework.shared.getConfig() {
            print("Config: \(config)")
        }
    case .failure(let error):
        print("Failed to fetch config: \(error)")
    }
}
```

### Getting Cached Configuration

```swift
if let config = IntegrationFramework.shared.getConfig() {
    print("Paywall URL: \(config.paywall)")
    print("Latest version: \(config.localization.version.latestVersion)")
}
```

### Logging Analytics Events

```swift
// Log various events
IntegrationFramework.shared.log(event: .paywallView)
IntegrationFramework.shared.log(event: .onboardingView(1))
IntegrationFramework.shared.log(event: .paywallCTAClick)
IntegrationFramework.shared.log(event: .conversion)
```

### Managing Purchases

```swift
import Combine

// Start purchase service
IntegrationFramework.shared.start {
    print("Purchase service initialized")
}

// Check subscription status
let isSubscribed = IntegrationFramework.shared.isSubscribed

// Observe subscription changes
IntegrationFramework.shared.isSubscribedSubject
    .sink { isSubscribed in
        print("Subscription status: \(isSubscribed)")
    }
    .store(in: &cancellables)

// Make a purchase
enum IAPProducts: String {
    case monthly = "com.yourapp.monthly"
    case yearly = "com.yourapp.yearly"
}

IntegrationFramework.shared.purchase(
    IAPProducts.yearly,
    cancelled: {
        print("Purchase cancelled")
    },
    completion: { result in
        switch result {
        case .success(let purchased):
            print("Purchase successful: \(purchased)")
        case .failure(let error):
            print("Purchase failed: \(error)")
        }
    }
)

// Restore purchases
IntegrationFramework.shared.restore { hasSubscription in
    print("Restore completed. Has subscription: \(hasSubscription)")
}
```

## API Reference

### IntegrationFramework

The main entry point for the framework.

**Properties:**
- `shared` - Singleton instance
- `baseURL` - Base URL for API requests
- `path` - API path for config endpoint
- `purchasesKey` - RevenueCat API key

**Methods:**
- `fetchConfig(completion:)` - Fetch remote configuration
- `getConfig()` - Get cached configuration
- `log(event:)` - Log analytics event
- `start(completion:)` - Initialize RevenueCat SDK
- `restore(completion:)` - Restore previous purchases
- `purchase(_:cancelled:completion:)` - Purchase a product
- `isSubscribed` - Current subscription status
- `isSubscribedSubject` - Publisher for subscription status changes

### ConfigResponse

Configuration response model containing:
- `status` - Status string
- `paywall` - Paywall URL
- `onboarding` - Onboarding URL
- `conversion` - Conversion tracking URL
- `view` - View tracking URL
- `viewNumber` - View number tracking URL
- `localization` - Localization settings including version info

### Event

Analytics events:
- `.onboardingView(Int)` - Onboarding screen view with screen number
- `.paywallView` - Paywall shown
- `.paywallCTAClick` - Paywall CTA button clicked
- `.paywallCloseClick` - Paywall close button clicked
- `.paywallPopUpCloseClick` - Payment popup closed
- `.conversion` - Conversion event

## Caching Strategy

The framework implements a two-tier caching strategy:
1. **In-Memory Cache**: Fast access to configuration data
2. **Disk Cache**: Persistent storage in the documents directory

Configuration is automatically saved to disk when fetched and loaded from disk when the app restarts.

## Thread Safety

All public APIs are thread-safe and can be called from any thread. Completion handlers are automatically dispatched to the main thread where appropriate.

## License

[Your License Here]

## Author

Alexey Savchenko
