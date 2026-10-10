import Application
import Domain
import Foundation

/// Marker type so Persistence builds before SwiftData records land in Phase 3.
public enum PersistenceModule: Sendable {
    public static let name = "Persistence"
}
