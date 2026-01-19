// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IntegrationFramework",
    platforms: [.iOS(.v17)],
    products: [.library(
        name: "IntegrationFramework",
        targets: ["IntegrationFramework"]
    )],
    dependencies: [
        .package(url: "https://github.com/RevenueCat/purchases-ios.git", exact: .init(5, 38, 2)),
    ],
    targets: [.target(
        name: "IntegrationFramework",
        dependencies: [
            .product(name: "RevenueCat", package: "purchases-ios"),
        ]
    )]
)
