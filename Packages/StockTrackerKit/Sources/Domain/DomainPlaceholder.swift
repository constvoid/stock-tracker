import Foundation

/// Marker type so the Domain target builds before real value types land in Phase 2.
public enum DomainModule: Sendable {
    public static let name = "Domain"
}
