import Application
import Domain
import Foundation

/// Marker type so MarketData builds before Yahoo-style adapters land in Phase 5.
public enum MarketDataModule: Sendable {
    public static let name = "MarketData"
}
