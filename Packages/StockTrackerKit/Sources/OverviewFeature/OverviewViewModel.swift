import Application
import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class OverviewViewModel {
    public private(set) var readModel: PortfolioOverviewReadModel?
    public private(set) var isLoading = false
    public private(set) var isRefreshing = false
    public private(set) var errorMessage: String?
    public private(set) var refreshBanner: String?
    public var expandedBrokerages: Set<String> = []

    private let getOverview: GetPortfolioOverview
    private let refreshMarketData: RefreshMarketData?

    public init(getOverview: GetPortfolioOverview, refreshMarketData: RefreshMarketData? = nil) {
        self.getOverview = getOverview
        self.refreshMarketData = refreshMarketData
    }

    public func load(refreshQuotes: Bool = false) async {
        if refreshQuotes {
            await refresh()
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            readModel = try await getOverview()
        } catch {
            errorMessage = "Couldn't load portfolio overview."
        }
    }

    public func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        if let refreshMarketData {
            let result = await refreshMarketData()
            if result.failed {
                refreshBanner = result.usedStaleCache
                    ? "Market data unavailable. Showing stale cached prices."
                    : "Market data unavailable. Showing imported prices."
            } else {
                refreshBanner = nil
            }
        }
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
