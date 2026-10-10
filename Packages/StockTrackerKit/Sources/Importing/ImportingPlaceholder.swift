import Application
import Domain
import Foundation

/// Marker type so Importing builds before Schwab/E*TRADE adapters land in Phase 3.
public enum ImportingModule: Sendable {
    public static let name = "Importing"
}
