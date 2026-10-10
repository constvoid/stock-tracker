import Domain
import Foundation
import PortfolioMath

public enum PortfolioFreshnessLabel: String, Hashable, Sendable {
    case imported
    case cached
    case fresh
    case stale
    case unavailable
}

public struct OverviewAccountRow: Hashable, Sendable, Identifiable {
    public var id: AccountID { accountID }
    public let accountID: AccountID
    public let brokerageID: BrokerageID
    public let brokerageName: String
    public let displayName: String
    public let totalValue: Money
    public let todayChange: Money?
    public let isStale: Bool
    public let isCashOnly: Bool

    public init(
        accountID: AccountID,
        brokerageID: BrokerageID,
        brokerageName: String,
        displayName: String,
        totalValue: Money,
        todayChange: Money?,
        isStale: Bool,
        isCashOnly: Bool
    ) {
        self.accountID = accountID
        self.brokerageID = brokerageID
        self.brokerageName = brokerageName
        self.displayName = displayName
        self.totalValue = totalValue
        self.todayChange = todayChange
        self.isStale = isStale
        self.isCashOnly = isCashOnly
    }
}

public struct OverviewBrokerageSection: Hashable, Sendable, Identifiable {
    public var id: BrokerageID { brokerageID }
    public let brokerageID: BrokerageID
    public let displayName: String
    public let totalValue: Money
    public let accounts: [OverviewAccountRow]

    public init(
        brokerageID: BrokerageID,
        displayName: String,
        totalValue: Money,
        accounts: [OverviewAccountRow]
    ) {
        self.brokerageID = brokerageID
        self.displayName = displayName
        self.totalValue = totalValue
        self.accounts = accounts
    }
}

public struct PortfolioOverviewReadModel: Hashable, Sendable {
    public let totalValue: Money
    public let todayChangeAmount: Money?
    public let todayChangePercent: Decimal?
    public let movers: Movers
    public let brokerages: [OverviewBrokerageSection]
    public let historyQuality: HistoryQuality
    public let freshness: PortfolioFreshnessLabel
    public let asOf: Date?
    public let disclosure: String?

    public init(
        totalValue: Money,
        todayChangeAmount: Money?,
        todayChangePercent: Decimal?,
        movers: Movers,
        brokerages: [OverviewBrokerageSection],
        historyQuality: HistoryQuality,
        freshness: PortfolioFreshnessLabel,
        asOf: Date?,
        disclosure: String?
    ) {
        self.totalValue = totalValue
        self.todayChangeAmount = todayChangeAmount
        self.todayChangePercent = todayChangePercent
        self.movers = movers
        self.brokerages = brokerages
        self.historyQuality = historyQuality
        self.freshness = freshness
        self.asOf = asOf
        self.disclosure = disclosure
    }

    public var isEmpty: Bool { brokerages.isEmpty }
}

public struct HoldingAllocationRow: Hashable, Sendable, Identifiable {
    public var id: AccountID { accountID }
    public let accountID: AccountID
    public let accountName: String
    public let brokerageName: String
    public let quantity: Quantity
    public let averageCost: Money
    public let marketValue: Money?

    public init(
        accountID: AccountID,
        accountName: String,
        brokerageName: String,
        quantity: Quantity,
        averageCost: Money,
        marketValue: Money?
    ) {
        self.accountID = accountID
        self.accountName = accountName
        self.brokerageName = brokerageName
        self.quantity = quantity
        self.averageCost = averageCost
        self.marketValue = marketValue
    }
}

public struct HoldingRowReadModel: Hashable, Sendable, Identifiable {
    public var id: String { canonicalSymbol.rawValue }
    public let canonicalSymbol: CanonicalSymbol
    public let displaySymbol: NativeSymbol
    public let securityName: String?
    public let quantity: Quantity
    public let currentPrice: Money?
    public let marketValue: Money?
    public let dayChange: Money?
    public let dayChangePercent: Decimal?
    public let averageCost: Money
    public let allocations: [HoldingAllocationRow]

    public init(
        canonicalSymbol: CanonicalSymbol,
        displaySymbol: NativeSymbol,
        securityName: String?,
        quantity: Quantity,
        currentPrice: Money?,
        marketValue: Money?,
        dayChange: Money?,
        dayChangePercent: Decimal?,
        averageCost: Money,
        allocations: [HoldingAllocationRow]
    ) {
        self.canonicalSymbol = canonicalSymbol
        self.displaySymbol = displaySymbol
        self.securityName = securityName
        self.quantity = quantity
        self.currentPrice = currentPrice
        self.marketValue = marketValue
        self.dayChange = dayChange
        self.dayChangePercent = dayChangePercent
        self.averageCost = averageCost
        self.allocations = allocations
    }
}

public struct CashBalanceRow: Hashable, Sendable, Identifiable {
    public var id: String { accountName }
    public let accountName: String
    public let cash: Money

    public init(accountName: String, cash: Money) {
        self.accountName = accountName
        self.cash = cash
    }
}

public struct PortfolioHoldingsReadModel: Hashable, Sendable {
    public let totalValue: Money
    public let todayChangeAmount: Money?
    public let todayChangePercent: Decimal?
    public let holdings: [HoldingRowReadModel]
    public let cashTotal: Money
    public let cashByAccount: [CashBalanceRow]
    public let freshness: PortfolioFreshnessLabel
    public let asOf: Date?

    public init(
        totalValue: Money,
        todayChangeAmount: Money?,
        todayChangePercent: Decimal?,
        holdings: [HoldingRowReadModel],
        cashTotal: Money,
        cashByAccount: [CashBalanceRow],
        freshness: PortfolioFreshnessLabel,
        asOf: Date?
    ) {
        self.totalValue = totalValue
        self.todayChangeAmount = todayChangeAmount
        self.todayChangePercent = todayChangePercent
        self.holdings = holdings
        self.cashTotal = cashTotal
        self.cashByAccount = cashByAccount
        self.freshness = freshness
        self.asOf = asOf
    }
}

public struct AccountPositionRow: Hashable, Sendable, Identifiable {
    public var id: String { canonicalSymbol.rawValue }
    public let canonicalSymbol: CanonicalSymbol
    public let displaySymbol: NativeSymbol
    public let securityName: String?
    public let quantity: Quantity
    public let currentPrice: Money?
    public let marketValue: Money?
    public let dayChange: Money?
    public let averageCost: Money
    public let unrealizedGain: Money?

    public init(
        canonicalSymbol: CanonicalSymbol,
        displaySymbol: NativeSymbol,
        securityName: String?,
        quantity: Quantity,
        currentPrice: Money?,
        marketValue: Money?,
        dayChange: Money?,
        averageCost: Money,
        unrealizedGain: Money?
    ) {
        self.canonicalSymbol = canonicalSymbol
        self.displaySymbol = displaySymbol
        self.securityName = securityName
        self.quantity = quantity
        self.currentPrice = currentPrice
        self.marketValue = marketValue
        self.dayChange = dayChange
        self.averageCost = averageCost
        self.unrealizedGain = unrealizedGain
    }
}

public struct AccountDetailReadModel: Hashable, Sendable {
    public let accountID: AccountID
    public let brokerageName: String
    public let displayName: String
    public let isEnabled: Bool
    public let isStale: Bool
    public let totalValue: Money
    public let equityValue: Money
    public let cash: Money
    public let todayChange: Money?
    public let positions: [AccountPositionRow]
    public let capabilities: AccountCapabilities
    public let freshness: PortfolioFreshnessLabel
    public let asOf: Date?
    public let isCashOnly: Bool

    public init(
        accountID: AccountID,
        brokerageName: String,
        displayName: String,
        isEnabled: Bool,
        isStale: Bool,
        totalValue: Money,
        equityValue: Money,
        cash: Money,
        todayChange: Money?,
        positions: [AccountPositionRow],
        capabilities: AccountCapabilities,
        freshness: PortfolioFreshnessLabel,
        asOf: Date?,
        isCashOnly: Bool
    ) {
        self.accountID = accountID
        self.brokerageName = brokerageName
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.isStale = isStale
        self.totalValue = totalValue
        self.equityValue = equityValue
        self.cash = cash
        self.todayChange = todayChange
        self.positions = positions
        self.capabilities = capabilities
        self.freshness = freshness
        self.asOf = asOf
        self.isCashOnly = isCashOnly
    }
}

public struct SettingsAccountRow: Hashable, Sendable, Identifiable {
    public var id: AccountID { accountID }
    public let accountID: AccountID
    public let brokerageName: String
    public let displayName: String
    public let isEnabled: Bool
    public let isStale: Bool
    public let totalValue: Money
    public let lastImportedAt: Date

    public init(
        accountID: AccountID,
        brokerageName: String,
        displayName: String,
        isEnabled: Bool,
        isStale: Bool,
        totalValue: Money,
        lastImportedAt: Date
    ) {
        self.accountID = accountID
        self.brokerageName = brokerageName
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.isStale = isStale
        self.totalValue = totalValue
        self.lastImportedAt = lastImportedAt
    }
}

public struct SettingsReadModel: Hashable, Sendable {
    public let accounts: [SettingsAccountRow]
    public let lastImportSummaries: [String]

    public init(accounts: [SettingsAccountRow], lastImportSummaries: [String]) {
        self.accounts = accounts
        self.lastImportSummaries = lastImportSummaries
    }
}
