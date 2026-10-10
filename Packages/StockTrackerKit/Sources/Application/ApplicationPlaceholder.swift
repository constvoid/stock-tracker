import Domain
import Foundation
import PortfolioMath

/// Marker type so Application builds before use cases land in later phases.
public enum ApplicationModule: Sendable {
    public static let name = "Application"
    public static let dependsOn = [DomainModule.name, PortfolioMathModule.name]
}
