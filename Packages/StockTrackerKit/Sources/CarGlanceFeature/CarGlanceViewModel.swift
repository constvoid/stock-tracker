import Application
import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class CarGlanceViewModel {
    public struct AccountRow: Identifiable, Hashable, Sendable {
        public var id: AccountID { accountID }
        public let accountID: AccountID
        public let title: String
        public let value: Money
        public let isStale: Bool

        public init(accountID: AccountID, title: String, value: Money, isStale: Bool) {
            self.accountID = accountID
            self.title = title
            self.value = value
            self.isStale = isStale
        }
    }

    public private(set) var totalValue: Money?
    public private(set) var todayChangeAmount: Money?
    public private(set) var todayChangePercent: Decimal?
    public private(set) var freshness: PortfolioFreshnessLabel = .unavailable
    public private(set) var asOf: Date?
    public private(set) var accounts: [AccountRow] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    public private(set) var refreshBanner: String?

    private let getOverview: GetPortfolioOverview
    private let refreshMarketData: RefreshMarketData?
    private let accountLimit: Int

    public init(
        getOverview: GetPortfolioOverview,
        refreshMarketData: RefreshMarketData? = nil,
        accountLimit: Int = 4
    ) {
        self.getOverview = getOverview
        self.refreshMarketData = refreshMarketData
        self.accountLimit = accountLimit
    }

    public var isEmpty: Bool {
        totalValue == nil && accounts.isEmpty
    }

    public func load(refreshQuotes: Bool = true) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if refreshQuotes, let refreshMarketData {
            let result = await refreshMarketData()
            refreshBanner = result.failed
                ? (result.usedStaleCache
                    ? "Showing stale prices"
                    : "Showing imported prices")
                : nil
        }

        do {
            let overview = try await getOverview()
            apply(overview)
        } catch {
            errorMessage = "Couldn't load glance."
        }
    }

    private func apply(_ overview: PortfolioOverviewReadModel) {
        totalValue = overview.totalValue
        todayChangeAmount = overview.todayChangeAmount
        todayChangePercent = overview.todayChangePercent
        freshness = overview.freshness
        asOf = overview.asOf

        let flattened = overview.brokerages.flatMap(\.accounts)
        accounts = flattened
            .sorted { $0.totalValue.amount > $1.totalValue.amount }
            .prefix(accountLimit)
            .map {
                AccountRow(
                    accountID: $0.accountID,
                    title: $0.displayName,
                    value: $0.totalValue,
                    isStale: $0.isStale
                )
            }
    }
}
