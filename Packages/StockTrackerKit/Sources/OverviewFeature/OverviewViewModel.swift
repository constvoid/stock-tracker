import Application
import DesignSystem
import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class OverviewViewModel {
    public private(set) var readModel: PortfolioOverviewReadModel?
    public private(set) var series: HistoricalSeries?
    public private(set) var selectedRange: TimeRange = .month
    public private(set) var isLoading = false
    public private(set) var isRefreshing = false
    public private(set) var errorMessage: String?
    public private(set) var refreshBanner: String?
    public var expandedBrokerages: Set<String> = []

    private let getOverview: GetPortfolioOverview
    private let refreshMarketData: RefreshMarketData?
    private let getHistoricalValue: GetHistoricalValue?

    public init(
        getOverview: GetPortfolioOverview,
        refreshMarketData: RefreshMarketData? = nil,
        getHistoricalValue: GetHistoricalValue? = nil
    ) {
        self.getOverview = getOverview
        self.refreshMarketData = refreshMarketData
        self.getHistoricalValue = getHistoricalValue
    }

    public var chartPoints: [ChartValuePoint] {
        (series?.points ?? []).map {
            ChartValuePoint(
                date: $0.timestamp,
                value: NSDecimalNumber(decimal: $0.value.amount).doubleValue
            )
        }
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
            await loadHistory()
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
            await loadHistory()
        } catch {
            errorMessage = "Couldn't load portfolio overview."
        }
    }

    public func selectRange(_ range: TimeRange) async {
        selectedRange = range
        await loadHistory()
    }

    public func selectRangeID(_ id: String) async {
        guard let range = TimeRange(rawValue: id) else { return }
        await selectRange(range)
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

    private func loadHistory() async {
        guard let getHistoricalValue else {
            series = nil
            return
        }
        do {
            series = try await getHistoricalValue(scope: .portfolio, range: selectedRange)
        } catch {
            series = HistoricalSeries(
                range: selectedRange,
                points: [],
                quality: readModel?.historyQuality ?? .reconstructed,
                disclosure: "Historical market data unavailable.",
                asOf: nil
            )
        }
    }
}
