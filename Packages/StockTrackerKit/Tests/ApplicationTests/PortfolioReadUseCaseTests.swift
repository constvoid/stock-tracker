import Application
import Domain
import Foundation
import Testing

@Test("UI-002 overview uses enabled accounts and imported quotes")
func overviewUsesEnabledAccounts() async throws {
    let repository = FakePortfolioRepository()
    let brokerage = BrokerageID("schwab")
    let enabledID = AccountID()
    let hiddenID = AccountID()
    let importedAt = Date(timeIntervalSince1970: 1_700_000_000)

    try await repository.seed(
        account: makeAccount(
            id: enabledID,
            brokerage: brokerage,
            name: "Enabled",
            enabled: true,
            cash: 100,
            symbol: "AAAX",
            quantity: 2,
            unitCost: 50,
            importedAt: importedAt
        ),
        quote: Quote(
            canonicalSymbol: CanonicalSymbol("AAAX"),
            price: try Money.usd(80),
            asOf: importedAt,
            source: .brokerImport,
            freshness: .fresh
        )
    )
    try await repository.seed(
        account: makeAccount(
            id: hiddenID,
            brokerage: brokerage,
            name: "Hidden",
            enabled: false,
            cash: 9_999,
            symbol: "BBBX",
            quantity: 10,
            unitCost: 10,
            importedAt: importedAt
        ),
        quote: Quote(
            canonicalSymbol: CanonicalSymbol("BBBX"),
            price: try Money.usd(20),
            asOf: importedAt,
            source: .brokerImport,
            freshness: .fresh
        )
    )

    let overview = try await GetPortfolioOverview(repository: repository)()
    // 2*80 + 100 = 260
    #expect(overview.totalValue.amount == 260)
    #expect(overview.brokerages.count == 1)
    #expect(overview.brokerages.first?.accounts.count == 1)
    #expect(overview.freshness == .imported)
}

@Test("UI-004 holdings aggregate symbols and expose cash summary")
func holdingsAggregateAndCash() async throws {
    let repository = FakePortfolioRepository()
    let brokerage = BrokerageID("schwab")
    let a = AccountID()
    let b = AccountID()
    let importedAt = Date(timeIntervalSince1970: 1_700_000_000)

    try await repository.seed(
        account: makeAccount(
            id: a,
            brokerage: brokerage,
            name: "A",
            enabled: true,
            cash: 50,
            symbol: "AAAX",
            quantity: 1,
            unitCost: 40,
            importedAt: importedAt
        ),
        quote: Quote(
            canonicalSymbol: CanonicalSymbol("AAAX"),
            price: try Money.usd(100),
            asOf: importedAt,
            source: .brokerImport,
            freshness: .fresh
        )
    )
    try await repository.seed(
        account: makeAccount(
            id: b,
            brokerage: brokerage,
            name: "B",
            enabled: true,
            cash: 25,
            symbol: "AAAX",
            quantity: 3,
            unitCost: 60,
            importedAt: importedAt
        ),
        quote: nil
    )

    let holdings = try await GetPortfolioHoldings(repository: repository)()
    #expect(holdings.holdings.count == 1)
    #expect(holdings.holdings[0].quantity.shares == 4)
    #expect(holdings.holdings[0].allocations.count == 2)
    #expect(holdings.cashTotal.amount == 75)
}

@Test("UI-004 / CALC-004 account detail hides tax term without dates")
func accountDetailTaxTermHiddenForAggregate() async throws {
    let repository = FakePortfolioRepository()
    let brokerage = BrokerageID("schwab")
    let id = AccountID()
    let importedAt = Date(timeIntervalSince1970: 1_700_000_000)
    try await repository.seed(
        account: makeAccount(
            id: id,
            brokerage: brokerage,
            name: "Agg",
            enabled: true,
            cash: 0,
            symbol: "AAAX",
            quantity: 1,
            unitCost: 10,
            importedAt: importedAt
        ),
        quote: Quote(
            canonicalSymbol: CanonicalSymbol("AAAX"),
            price: try Money.usd(12),
            asOf: importedAt,
            source: .brokerImport,
            freshness: .fresh
        )
    )

    let detail = try #require(try await GetAccountDetail(repository: repository)(accountID: id))
    #expect(detail.capabilities.taxTerm == .unavailableMissingAcquisitionDates)
    #expect(detail.totalValue.amount == 12)
}

private func makeAccount(
    id: AccountID,
    brokerage: BrokerageID,
    name: String,
    enabled: Bool,
    cash: Decimal,
    symbol: String,
    quantity: Decimal,
    unitCost: Decimal,
    importedAt: Date
) throws -> BrokerageAccount {
    let provenance = ImportProvenance(
        parserIdentifier: "test",
        parserVersion: 1,
        importedAt: importedAt
    )
    let slice = try PositionSlice(
        accountID: id,
        nativeSymbol: NativeSymbol(symbol),
        canonicalSymbol: CanonicalSymbol(symbol),
        securityKind: .equity,
        quantity: Quantity(shares: quantity),
        unitCost: UnitCost.usd(unitCost),
        acquiredAt: nil,
        basisKind: .aggregatePosition,
        provenance: provenance
    )
    return BrokerageAccount(
        id: id,
        brokerageID: brokerage,
        sourceKey: SourceAccountKey(brokerageID: brokerage, externalReference: name),
        sourceDisplayName: name,
        cash: try Money.usd(cash),
        isEnabled: enabled,
        lastImportedAt: importedAt,
        slices: [slice]
    )
}

actor FakePortfolioRepository: PortfolioRepository {
    private var accounts: [AccountID: BrokerageAccount] = [:]
    private var quotes: [CanonicalSymbol: Quote] = [:]

    func seed(account: BrokerageAccount, quote: Quote?) async throws {
        accounts[account.id] = account
        if let quote {
            quotes[quote.canonicalSymbol] = quote
        }
    }

    func portfolioSnapshot() async throws -> PortfolioSnapshot {
        let brokerages = Dictionary(grouping: accounts.values, by: \.brokerageID).keys.map {
            Brokerage(id: $0, displayName: $0.rawValue)
        }
        return PortfolioSnapshot(brokerages: brokerages, accounts: Array(accounts.values))
    }

    func account(id: AccountID) async throws -> BrokerageAccount? { accounts[id] }
    func account(sourceKey: SourceAccountKey) async throws -> BrokerageAccount? {
        accounts.values.first { $0.sourceKey == sourceKey }
    }

    func replaceAccount(_ snapshot: AccountReplacementSnapshot, audit: ImportAuditMetadata) async throws -> AccountID {
        _ = snapshot
        _ = audit
        return AccountID()
    }

    func markMissingAccountsStale(
        brokerageID: BrokerageID,
        presentKeys: [SourceAccountKey],
        asOf: Date
    ) async throws -> [AccountID] {
        _ = brokerageID
        _ = presentKeys
        _ = asOf
        return []
    }

    func setAccountEnabled(id: AccountID, enabled: Bool) async throws {
        guard var account = accounts[id] else { return }
        account = BrokerageAccount(
            id: account.id,
            brokerageID: account.brokerageID,
            sourceKey: account.sourceKey,
            sourceDisplayName: account.sourceDisplayName,
            displayNameOverride: account.displayNameOverride,
            kindHint: account.kindHint,
            cash: account.cash,
            isEnabled: enabled,
            freshness: account.freshness,
            sourceAsOf: account.sourceAsOf,
            lastImportedAt: account.lastImportedAt,
            slices: account.slices
        )
        accounts[id] = account
    }

    func deleteStaleAccount(id: AccountID) async throws { accounts[id] = nil }

    func cachedQuotes(symbols: [CanonicalSymbol]) async throws -> [CanonicalSymbol: Quote] {
        var result: [CanonicalSymbol: Quote] = [:]
        for symbol in symbols where quotes[symbol] != nil {
            result[symbol] = quotes[symbol]
        }
        return result
    }

    func saveQuotes(_ quotes: [Quote]) async throws {
        for quote in quotes { self.quotes[quote.canonicalSymbol] = quote }
    }

    func cachedBars(
        symbols: [CanonicalSymbol],
        interval: PriceBarInterval,
        from: Date,
        to: Date
    ) async throws -> [CanonicalSymbol: [PriceBar]] {
        [:]
    }

    func saveBars(_ bars: [PriceBar]) async throws {}
}
