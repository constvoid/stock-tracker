import Application
import Domain
import Foundation
import MarketData
import Testing

@Test("MKT-002 network failure marks cache stale and never clears holdings")
func refreshFailureKeepsHoldingsMarksStale() async throws {
    let repository = FakePortfolioRepository()
    let brokerage = BrokerageID("schwab")
    let accountID = AccountID()
    let importedAt = Date(timeIntervalSince1970: 1_700_000_000)
    try await repository.seed(
        account: try makeRefreshAccount(
            id: accountID,
            brokerage: brokerage,
            importedAt: importedAt
        ),
        quote: Quote(
            canonicalSymbol: CanonicalSymbol("AAAX"),
            price: try Money.usd(100),
            previousClose: try Money.usd(90),
            asOf: importedAt,
            source: .brokerImport,
            freshness: .fresh,
            session: .regular
        )
    )

    let before = try await repository.portfolioSnapshot()
    #expect(before.accounts.first?.slices.count == 1)

    let refresh = RefreshMarketData(
        repository: repository,
        quoteProvider: FakeQuoteProvider(shouldFail: true)
    )
    let result = await refresh()
    #expect(result.failed)
    #expect(result.usedStaleCache)

    let after = try await repository.portfolioSnapshot()
    #expect(after.accounts.first?.slices.count == 1)
    let cached = try await repository.cachedQuotes(symbols: [CanonicalSymbol("AAAX")])
    #expect(cached[CanonicalSymbol("AAAX")]?.freshness == .stale)
    #expect(cached[CanonicalSymbol("AAAX")]?.price.amount == 100)
}

@Test("MKT-001 / MKT-004 successful refresh stores provider quotes with previous close")
func refreshStoresProviderQuotes() async throws {
    let repository = FakePortfolioRepository()
    let brokerage = BrokerageID("schwab")
    let accountID = AccountID()
    let importedAt = Date(timeIntervalSince1970: 1_700_000_000)
    try await repository.seed(
        account: try makeRefreshAccount(
            id: accountID,
            brokerage: brokerage,
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

    let providerQuote = Quote(
        canonicalSymbol: CanonicalSymbol("AAAX"),
        price: try Money.usd(110),
        previousClose: try Money.usd(100),
        asOf: Date(timeIntervalSince1970: 1_700_000_100),
        source: .marketProvider,
        freshness: .fresh,
        session: .post
    )
    let refresh = RefreshMarketData(
        repository: repository,
        quoteProvider: FakeQuoteProvider(quotesBySymbol: [CanonicalSymbol("AAAX"): providerQuote])
    )
    let result = await refresh(now: Date(timeIntervalSince1970: 1_700_000_120))
    #expect(!result.failed)
    #expect(result.updatedSymbols.map(\.rawValue) == ["AAAX"])

    let cached = try await repository.cachedQuotes(symbols: [CanonicalSymbol("AAAX")])
    #expect(cached[CanonicalSymbol("AAAX")]?.price.amount == 110)
    #expect(cached[CanonicalSymbol("AAAX")]?.previousClose?.amount == 100)
    #expect(cached[CanonicalSymbol("AAAX")]?.session == .post)
    #expect(cached[CanonicalSymbol("AAAX")]?.source == .marketProvider)

    let overview = try await GetPortfolioOverview(repository: repository)()
    // 2 shares × ($110 − $100 previous close) = $20
    #expect(overview.todayChangeAmount?.amount == 20)
    #expect(!overview.movers.gainers.isEmpty || overview.todayChangeAmount != nil)
}

private func makeRefreshAccount(
    id: AccountID,
    brokerage: BrokerageID,
    importedAt: Date
) throws -> BrokerageAccount {
    let slice = try PositionSlice(
        accountID: id,
        nativeSymbol: NativeSymbol("AAAX"),
        canonicalSymbol: CanonicalSymbol("AAAX"),
        securityKind: .equity,
        quantity: Quantity(shares: 2),
        unitCost: UnitCost.usd(50),
        acquiredAt: nil,
        basisKind: .aggregatePosition,
        provenance: ImportProvenance(parserIdentifier: "test", parserVersion: 1, importedAt: importedAt)
    )
    return BrokerageAccount(
        id: id,
        brokerageID: brokerage,
        sourceKey: SourceAccountKey(brokerageID: brokerage, externalReference: "1"),
        sourceDisplayName: "Test",
        cash: try Money.usd(0),
        lastImportedAt: importedAt,
        slices: [slice]
    )
}
