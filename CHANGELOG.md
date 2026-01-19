# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of IntegrationFramework
- Configuration management with automatic caching
- Analytics event tracking
- RevenueCat integration for in-app purchases
- Swift 6 concurrency support with full Sendable compliance
- Two-tier caching strategy (in-memory + disk persistence)
- Automatic device ID generation and persistence

### Features
- `ConfigService`: Fetch and cache remote configuration
- `AnalyticsService`: Track and send analytics events
- `PurchaseService`: Manage subscriptions and purchases via RevenueCat
- Thread-safe singleton instances
- Automatic main thread dispatch for completion handlers

### Technical
- Built with Swift 6.0
- Full `@Sendable` compliance for concurrency safety
- `@unchecked Sendable` for managed shared state
- Comprehensive error handling
- Supports iOS 13.0+
