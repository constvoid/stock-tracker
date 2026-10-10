import Domain
import Foundation
import PortfolioMath

public struct GetPortfolioOverview: Sendable {
    private let repository: any PortfolioRepository

    public init(repository: any PortfolioRepository) {
        self.repository = repository
    }

    public func callAsFunction() async throws -> PortfolioOverviewReadModel {
        let snapshot = try await repository.portfolioSnapshot()
        let quotes = try await loadQuotes(for: snapshot.accounts)
        let rollup = try RollupMath.portfolioRollup(accounts: snapshot.accounts, quotes: quotes)
        let movers = MoversMath.movers(holdings: rollup.holdings)
        let today = try todayChange(from: rollup.holdings)
        let brokerages = try brokerageSections(snapshot: snapshot, rollup: rollup, quotes: quotes)
        let quality = CapabilityDerivation.portfolioHistoryQuality(accounts: snapshot.accounts)
        let asOf = quotes.values.map(\.asOf).max()
            ?? snapshot.accounts.compactMap(\.sourceAsOf).max()
        let freshness = freshnessLabel(quotes: quotes, accounts: snapshot.accounts)

        return PortfolioOverviewReadModel(
            totalValue: rollup.totalValue,
            todayChangeAmount: today.amount,
            todayChangePercent: today.percent,
            movers: movers,
            brokerages: brokerages,
            historyQuality: quality,
            freshness: freshness,
            asOf: asOf,
            disclosure: quality == .estimatedUnknownAcquisitionDates
                ? "Chart history will be estimated when some positions lack acquisition dates."
                : nil
        )
    }
}

public struct GetPortfolioHoldings: Sendable {
    private let repository: any PortfolioRepository

    public init(repository: any PortfolioRepository) {
        self.repository = repository
    }

    public func callAsFunction() async throws -> PortfolioHoldingsReadModel {
        let snapshot = try await repository.portfolioSnapshot()
        let quotes = try await loadQuotes(for: snapshot.accounts)
        let enabled = snapshot.accounts.filter(\.isEnabled)
        let rollup = try RollupMath.portfolioRollup(accounts: snapshot.accounts, quotes: quotes)
        let accountsByID = Dictionary(uniqueKeysWithValues: enabled.map { ($0.id, $0) })
        let brokerageNames = Dictionary(
            uniqueKeysWithValues: snapshot.brokerages.map { ($0.id, $0.displayName) }
        )

        let holdings: [HoldingRowReadModel] = try rollup.holdings
            .sorted { ($0.marketValue?.amount ?? 0) > ($1.marketValue?.amount ?? 0) }
            .map { holding in
                let allocations: [HoldingAllocationRow] = try holding.accountAllocations.keys.sorted {
                    $0.rawValue.uuidString < $1.rawValue.uuidString
                }.compactMap { accountID in
                    guard let account = accountsByID[accountID],
                          let quantity = holding.accountAllocations[accountID]
                    else { return nil }
                    let accountPositions = try PositionDerivation.positions(
                        from: account.slices.filter { $0.canonicalSymbol == holding.canonicalSymbol },
                        quotes: quotes
                    )
                    let average = accountPositions.first?.averageCost ?? holding.averageCost
                    let marketValue = accountPositions.first?.marketValue
                    return HoldingAllocationRow(
                        accountID: accountID,
                        accountName: account.displayName,
                        brokerageName: brokerageNames[account.brokerageID] ?? account.brokerageID.rawValue,
                        quantity: quantity,
                        averageCost: average,
                        marketValue: marketValue
                    )
                }
                let percent: Decimal?
                if let day = holding.dayChange?.amount,
                   let market = holding.marketValue?.amount {
                    let previous = market - day
                    percent = previous == 0 ? 0 : day / previous
                } else {
                    percent = nil
                }
                let name = enabled
                    .flatMap(\.slices)
                    .first { $0.canonicalSymbol == holding.canonicalSymbol }?
                    .securityName
                return HoldingRowReadModel(
                    canonicalSymbol: holding.canonicalSymbol,
                    displaySymbol: holding.displaySymbol,
                    securityName: name,
                    quantity: holding.quantity,
                    currentPrice: holding.currentPrice,
                    marketValue: holding.marketValue,
                    dayChange: holding.dayChange,
                    dayChangePercent: percent,
                    averageCost: holding.averageCost,
                    allocations: allocations
                )
            }

        let today = try todayChange(from: rollup.holdings)
        let cashByAccount = enabled
            .filter { $0.cash.amount != 0 }
            .map { CashBalanceRow(accountName: $0.displayName, cash: $0.cash) }
            .sorted { $0.accountName < $1.accountName }

        return PortfolioHoldingsReadModel(
            totalValue: rollup.totalValue,
            todayChangeAmount: today.amount,
            todayChangePercent: today.percent,
            holdings: holdings,
            cashTotal: rollup.cashValue,
            cashByAccount: cashByAccount,
            freshness: freshnessLabel(quotes: quotes, accounts: enabled),
            asOf: quotes.values.map(\.asOf).max()
        )
    }
}

public struct GetAccountDetail: Sendable {
    private let repository: any PortfolioRepository

    public init(repository: any PortfolioRepository) {
        self.repository = repository
    }

    public func callAsFunction(accountID: AccountID) async throws -> AccountDetailReadModel? {
        guard let account = try await repository.account(id: accountID) else { return nil }
        let snapshot = try await repository.portfolioSnapshot()
        let brokerageName = snapshot.brokerages.first { $0.id == account.brokerageID }?.displayName
            ?? account.brokerageID.rawValue
        let quotes = try await loadQuotes(for: [account])
        let rollup = try RollupMath.accountRollup(account: account, quotes: quotes)
        let capabilities = CapabilityDerivation.accountCapabilities(slices: account.slices)
        let todayChange = try rollup.positions.reduce(Optional(try Money.zero())) { partial, position in
            guard let partial, let day = position.dayChange else { return partial }
            return try partial + day
        }
        let positions = rollup.positions
            .sorted { ($0.marketValue?.amount ?? 0) > ($1.marketValue?.amount ?? 0) }
            .map { position in
                AccountPositionRow(
                    canonicalSymbol: position.canonicalSymbol,
                    displaySymbol: position.displaySymbol,
                    securityName: position.slices.first?.securityName,
                    quantity: position.quantity,
                    currentPrice: position.currentPrice,
                    marketValue: position.marketValue,
                    dayChange: position.dayChange,
                    averageCost: position.averageCost,
                    unrealizedGain: position.unrealizedGain
                )
            }

        let isStale: Bool
        if case .stale = account.freshness { isStale = true } else { isStale = false }

        return AccountDetailReadModel(
            accountID: account.id,
            brokerageName: brokerageName,
            displayName: account.displayName,
            isEnabled: account.isEnabled,
            isStale: isStale,
            totalValue: rollup.totalValue,
            equityValue: rollup.equityValue,
            cash: rollup.cash,
            todayChange: todayChange,
            positions: positions,
            capabilities: capabilities,
            freshness: freshnessLabel(quotes: quotes, accounts: [account]),
            asOf: quotes.values.map(\.asOf).max() ?? account.sourceAsOf,
            isCashOnly: account.isCashOnly
        )
    }
}

public struct GetSettingsAccounts: Sendable {
    private let repository: any PortfolioRepository

    public init(repository: any PortfolioRepository) {
        self.repository = repository
    }

    public func callAsFunction() async throws -> SettingsReadModel {
        let snapshot = try await repository.portfolioSnapshot()
        let quotes = try await loadQuotes(for: snapshot.accounts)
        let brokerageNames = Dictionary(
            uniqueKeysWithValues: snapshot.brokerages.map { ($0.id, $0.displayName) }
        )
        let rows: [SettingsAccountRow] = try snapshot.accounts.map { account in
            let rollup = try RollupMath.accountRollup(account: account, quotes: quotes)
            let isStale: Bool
            if case .stale = account.freshness { isStale = true } else { isStale = false }
            return SettingsAccountRow(
                accountID: account.id,
                brokerageName: brokerageNames[account.brokerageID] ?? account.brokerageID.rawValue,
                displayName: account.displayName,
                isEnabled: account.isEnabled,
                isStale: isStale,
                totalValue: rollup.totalValue,
                lastImportedAt: account.lastImportedAt
            )
        }
        .sorted {
            if $0.brokerageName == $1.brokerageName {
                return $0.displayName < $1.displayName
            }
            return $0.brokerageName < $1.brokerageName
        }

        let summaries = snapshot.brokerages.compactMap { brokerage -> String? in
            guard let at = brokerage.lastCompleteImportAt else { return nil }
            return "\(brokerage.displayName): last import \(at.formatted(date: .abbreviated, time: .shortened))"
        }

        return SettingsReadModel(accounts: rows, lastImportSummaries: summaries)
    }
}

public struct SetAccountVisibility: Sendable {
    private let repository: any PortfolioRepository

    public init(repository: any PortfolioRepository) {
        self.repository = repository
    }

    public func callAsFunction(accountID: AccountID, enabled: Bool) async throws {
        try await repository.setAccountEnabled(id: accountID, enabled: enabled)
    }
}

public enum StaleAccountAction: String, Sendable {
    case keep
    case hide
    case delete
}

public struct ResolveStaleAccount: Sendable {
    private let repository: any PortfolioRepository

    public init(repository: any PortfolioRepository) {
        self.repository = repository
    }

    public func callAsFunction(accountID: AccountID, action: StaleAccountAction) async throws {
        switch action {
        case .keep:
            break
        case .hide:
            try await repository.setAccountEnabled(id: accountID, enabled: false)
        case .delete:
            try await repository.deleteStaleAccount(id: accountID)
        }
    }
}

// MARK: - Shared helpers

private extension GetPortfolioOverview {
    func loadQuotes(for accounts: [BrokerageAccount]) async throws -> [CanonicalSymbol: Quote] {
        let symbols = Array(Set(accounts.flatMap(\.slices).map(\.canonicalSymbol)))
        return try await repository.cachedQuotes(symbols: symbols)
    }

    func brokerageSections(
        snapshot: PortfolioSnapshot,
        rollup: PortfolioRollup,
        quotes: [CanonicalSymbol: Quote]
    ) throws -> [OverviewBrokerageSection] {
        let enabled = snapshot.accounts.filter(\.isEnabled)
        let brokerageNames = Dictionary(
            uniqueKeysWithValues: snapshot.brokerages.map { ($0.id, $0.displayName) }
        )
        let rollupsByID = Dictionary(uniqueKeysWithValues: rollup.accountRollups.map { ($0.accountID, $0) })
        let grouped = Dictionary(grouping: enabled, by: \.brokerageID)

        return try grouped.keys.sorted { $0.rawValue < $1.rawValue }.compactMap { brokerageID in
            guard let accounts = grouped[brokerageID] else { return nil }
            let rows: [OverviewAccountRow] = try accounts.map { account in
                let accountRollup: AccountRollup
                if let existing = rollupsByID[account.id] {
                    accountRollup = existing
                } else {
                    accountRollup = try RollupMath.accountRollup(account: account, quotes: quotes)
                }
                var todayTotal = try Money.zero()
                var hasToday = false
                for position in accountRollup.positions {
                    if let day = position.dayChange {
                        todayTotal = try todayTotal + day
                        hasToday = true
                    }
                }
                let today: Money? = hasToday ? todayTotal : nil
                let isStale: Bool
                if case .stale = account.freshness { isStale = true } else { isStale = false }
                return OverviewAccountRow(
                    accountID: account.id,
                    brokerageID: brokerageID,
                    brokerageName: brokerageNames[brokerageID] ?? brokerageID.rawValue,
                    displayName: account.displayName,
                    totalValue: accountRollup.totalValue,
                    todayChange: today,
                    isStale: isStale,
                    isCashOnly: account.isCashOnly
                )
            }
            .sorted { $0.displayName < $1.displayName }
            let total = try rows.reduce(try Money.zero()) { try $0 + $1.totalValue }
            return OverviewBrokerageSection(
                brokerageID: brokerageID,
                displayName: brokerageNames[brokerageID] ?? brokerageID.rawValue,
                totalValue: total,
                accounts: rows
            )
        }
    }
}

private extension GetPortfolioHoldings {
    func loadQuotes(for accounts: [BrokerageAccount]) async throws -> [CanonicalSymbol: Quote] {
        let symbols = Array(Set(accounts.flatMap(\.slices).map(\.canonicalSymbol)))
        return try await repository.cachedQuotes(symbols: symbols)
    }
}

private extension GetAccountDetail {
    func loadQuotes(for accounts: [BrokerageAccount]) async throws -> [CanonicalSymbol: Quote] {
        let symbols = Array(Set(accounts.flatMap(\.slices).map(\.canonicalSymbol)))
        return try await repository.cachedQuotes(symbols: symbols)
    }
}

private extension GetSettingsAccounts {
    func loadQuotes(for accounts: [BrokerageAccount]) async throws -> [CanonicalSymbol: Quote] {
        let symbols = Array(Set(accounts.flatMap(\.slices).map(\.canonicalSymbol)))
        return try await repository.cachedQuotes(symbols: symbols)
    }
}

private func todayChange(from holdings: [PortfolioHolding]) throws -> (amount: Money?, percent: Decimal?) {
    var total = try Money.zero()
    var hasAny = false
    for holding in holdings {
        if let day = holding.dayChange {
            total = try total + day
            hasAny = true
        }
    }
    guard hasAny else { return (nil, nil) }
    let market = holdings.compactMap { $0.marketValue?.amount }.reduce(Decimal(0), +)
    let previous = market - total.amount
    let percent = previous == 0 ? Decimal(0) : total.amount / previous
    return (total, percent)
}

private func freshnessLabel(
    quotes: [CanonicalSymbol: Quote],
    accounts: [BrokerageAccount]
) -> PortfolioFreshnessLabel {
    if accounts.isEmpty { return .unavailable }
    if quotes.isEmpty { return .imported }
    if quotes.values.contains(where: { $0.freshness == .stale }) { return .stale }
    if quotes.values.allSatisfy({ $0.source == .brokerImport }) { return .imported }
    return .fresh
}
