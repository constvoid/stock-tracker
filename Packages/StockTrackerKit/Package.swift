// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StockTrackerKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15), // enables `swift test` on the Mac host; app target remains iOS-only
    ],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "PortfolioMath", targets: ["PortfolioMath"]),
        .library(name: "Application", targets: ["Application"]),
        .library(name: "Importing", targets: ["Importing"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "MarketData", targets: ["MarketData"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "OverviewFeature", targets: ["OverviewFeature"]),
        .library(name: "HoldingsFeature", targets: ["HoldingsFeature"]),
        .library(name: "AccountDetailFeature", targets: ["AccountDetailFeature"]),
        .library(name: "ImportSettingsFeature", targets: ["ImportSettingsFeature"]),
        .library(name: "CarGlanceFeature", targets: ["CarGlanceFeature"]),
    ],
    targets: [
        .target(name: "Domain"),
        .target(
            name: "PortfolioMath",
            dependencies: ["Domain"]
        ),
        .target(
            name: "Application",
            dependencies: ["Domain", "PortfolioMath"]
        ),
        .target(
            name: "Importing",
            dependencies: ["Domain", "Application"]
        ),
        .target(
            name: "Persistence",
            dependencies: ["Domain", "Application"]
        ),
        .target(
            name: "MarketData",
            dependencies: ["Domain", "Application"]
        ),
        .target(
            name: "DesignSystem"
        ),
        .target(
            name: "OverviewFeature",
            dependencies: ["Domain", "Application", "DesignSystem"]
        ),
        .target(
            name: "HoldingsFeature",
            dependencies: ["Domain", "Application", "DesignSystem"]
        ),
        .target(
            name: "AccountDetailFeature",
            dependencies: ["Domain", "Application", "DesignSystem"]
        ),
        .target(
            name: "ImportSettingsFeature",
            dependencies: ["Domain", "Application", "DesignSystem"]
        ),
        .target(
            name: "CarGlanceFeature",
            dependencies: ["Domain", "Application", "DesignSystem"]
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"]
        ),
        .testTarget(
            name: "PortfolioMathTests",
            dependencies: ["PortfolioMath", "Domain"]
        ),
        .testTarget(
            name: "ApplicationTests",
            dependencies: ["Application", "Domain"]
        ),
        .testTarget(
            name: "ImportingTests",
            dependencies: ["Importing", "Domain", "Application"]
        ),
        .testTarget(
            name: "PersistenceTests",
            dependencies: ["Persistence", "Domain", "Application"]
        ),
    ]
)
