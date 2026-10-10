import Domain
import Foundation

/// Marker type so PortfolioMath builds before calculation APIs land in Phase 2.
public enum PortfolioMathModule: Sendable {
    public static let name = "PortfolioMath"
    public static let dependsOnDomain = DomainModule.name
}
