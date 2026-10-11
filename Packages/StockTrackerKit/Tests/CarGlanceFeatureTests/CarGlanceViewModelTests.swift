import Application
import CarGlanceFeature
import Domain
import Foundation
import Testing

@Test("CAR-001 glance maps overview to total, change, and few accounts")
@MainActor
func glanceMapsOverview() async throws {
    let repository = GlanceFakeRepository()
    let brokerage = BrokerageID("schwab")
    let importedAt = Date(timeIntervalSince1970: 1_700_000_000)

    for (index, name) in ["A", "B", "C", "D", "E"].enumerated() {
        let id = AccountID()
        try await repository.seed(
            account: BrokerageAccount(
                id: id,
                brokerageID: brokerage,
                sourceKey: SourceAccountKey(brokerageID: brokerage, externalReference: "\(index)"),
                sourceDisplayName: name,
                cash: try Money.usd(Decimal(100 * (5 - index))),
                lastImportedAt: importedAt,
                slices: []
            ),
            quote: nil
        )
    }

    let viewModel = CarGlanceViewModel(
        getOverview: GetPortfolioOverview(repository: repository),
        refreshMarketData: nil,
        accountLimit: 4
    )
    await viewModel.load(refreshQuotes: false)

    #expect(viewModel.totalValue?.amount == 1500) // 500+400+300+200+100
    #expect(viewModel.accounts.count == 4)
    #expect(viewModel.accounts.map(\.title) == ["A", "B", "C", "D"])
    #expect(viewModel.accounts.allSatisfy { $0.title != "E" })
}

actor GlanceFakeRepository: PortfolioRepository {
    private var accounts: [AccountID: BrokerageAccount] = [:]
    private var quotes: [CanonicalSymbol: Quote] = [:]

    func seed(account: BrokerageAccount, quote: Quote?) async throws {
        accounts[account.id] = account
        if let quote { quotes[quote.canonicalSymbol] = quote }
    }

    func portfolioSnapshot() async throws -> PortfolioSnapshot {
        PortfolioSnapshot(
            brokerages: [Brokerage(id: BrokerageID("schwab"), displayName: "Schwab")],
            accounts: Array(accounts.values)
        )
    }

    func account(id: AccountID) async throws -> BrokerageAccount? { accounts[id] }
    func account(sourceKey: SourceAccountKey) async throws -> BrokerageAccount? {
        accounts.values.first { $0.sourceKey == sourceKey }
    }

    func replaceAccount(_ snapshot: AccountReplacementSnapshot, audit: ImportAuditMetadata) async throws -> AccountID {
        _ = snapshot; _ = audit; return AccountID()
    }

    func markMissingAccountsStale(
        brokerageID: BrokerageID,
        presentKeys: [SourceAccountKey],
        asOf: Date
    ) async throws -> [AccountID] { [] }

    func setAccountEnabled(id: AccountID, enabled: Bool) async throws {}
    func deleteStaleAccount(id: AccountID) async throws {}

    func cachedQuotes(symbols: [CanonicalSymbol]) async throws -> [CanonicalSymbol: Quote] {
        var result: [CanonicalSymbol: Quote] = [:]
        for symbol in symbols where quotes[symbol] != nil { result[symbol] = quotes[symbol] }
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
    ) async throws -> [CanonicalSymbol: [PriceBar]] { [:] }

    func saveBars(_ bars: [PriceBar]) async throws {}
}
