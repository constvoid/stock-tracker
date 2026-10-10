import Application
import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class OverviewViewModel {
    public private(set) var readModel: PortfolioOverviewReadModel?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    public var expandedBrokerages: Set<String> = []

    private let getOverview: GetPortfolioOverview

    public init(getOverview: GetPortfolioOverview) {
        self.getOverview = getOverview
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            readModel = try await getOverview()
        } catch {
            errorMessage = "Couldn't load portfolio overview."
        }
    }

    public func toggleBrokerage(_ id: BrokerageID) {
        let key = id.rawValue
        if expandedBrokerages.contains(key) {
            expandedBrokerages.remove(key)
        } else {
            expandedBrokerages.insert(key)
        }
    }

    public func isExpanded(_ id: BrokerageID) -> Bool {
        expandedBrokerages.contains(id.rawValue)
    }
}
