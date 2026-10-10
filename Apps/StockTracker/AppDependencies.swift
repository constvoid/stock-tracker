import Application
import Domain
import Foundation
import Importing
import MarketData
import Persistence
import SwiftData

/// Composition root. Constructed once and passed explicitly — no service locator.
@MainActor
final class AppDependencies {
    let portfolioRepository: any PortfolioRepository
    let brokerageImporting: any BrokerageImporting
    let quoteProviding: any QuoteProviding
    let getOverview: GetPortfolioOverview
    let getHoldings: GetPortfolioHoldings
    let getAccountDetail: GetAccountDetail
    let getSettings: GetSettingsAccounts
    let previewImports: PreviewBrokerageImports
    let commitImports: CommitAccountImports
    let setVisibility: SetAccountVisibility
    let resolveStale: ResolveStaleAccount
    let refreshMarketData: RefreshMarketData
    let getHistoricalValue: GetHistoricalValue

    init(
        portfolioRepository: any PortfolioRepository,
        brokerageImporting: any BrokerageImporting,
        quoteProviding: any QuoteProviding,
        intraday: any IntradayPriceProviding,
        daily: any HistoricalPriceProviding
    ) {
        self.portfolioRepository = portfolioRepository
        self.brokerageImporting = brokerageImporting
        self.quoteProviding = quoteProviding
        self.getOverview = GetPortfolioOverview(repository: portfolioRepository)
        self.getHoldings = GetPortfolioHoldings(repository: portfolioRepository)
        self.getAccountDetail = GetAccountDetail(repository: portfolioRepository)
        self.getSettings = GetSettingsAccounts(repository: portfolioRepository)
        self.previewImports = PreviewBrokerageImports(repository: portfolioRepository)
        self.commitImports = CommitAccountImports(repository: portfolioRepository)
        self.setVisibility = SetAccountVisibility(repository: portfolioRepository)
        self.resolveStale = ResolveStaleAccount(repository: portfolioRepository)
        self.refreshMarketData = RefreshMarketData(
            repository: portfolioRepository,
            quoteProvider: quoteProviding
        )
        self.getHistoricalValue = GetHistoricalValue(
            repository: portfolioRepository,
            intraday: intraday,
            daily: daily
        )
    }

    static func makeLocal() throws -> AppDependencies {
        let schema = Schema(versionedSchema: PortfolioSchemaV1.self)
        let configuration = ModelConfiguration(
            "StockTracker",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        let container = try ModelContainer(
            for: schema,
            migrationPlan: PortfolioMigrationPlan.self,
            configurations: [configuration]
        )
        return AppDependencies(
            portfolioRepository: SwiftDataPortfolioRepository(modelContainer: container),
            brokerageImporting: FileBrokerageImporting(),
            quoteProviding: YahooStyleQuoteProvider(includeExtendedHours: true),
            intraday: YahooStyleIntradayProvider(includeExtendedHours: true),
            daily: YahooStyleHistoricalProvider()
        )
    }

    static func makeDeterministicFakes() -> AppDependencies {
        AppDependencies(
            portfolioRepository: InMemoryPortfolioRepository(),
            brokerageImporting: FileBrokerageImporting(
                clock: { Date(timeIntervalSince1970: 1_700_000_000) }
            ),
            quoteProviding: FakeQuoteProvider(shouldFail: true),
            intraday: FakeIntradayProvider(),
            daily: FakeHistoricalProvider()
        )
    }
}

/// Deterministic in-memory repository for previews/tests without SwiftData.
actor InMemoryPortfolioRepository: PortfolioRepository {
    private var accounts: [AccountID: BrokerageAccount] = [:]
    private var brokerages: [BrokerageID: Brokerage] = [:]
    private var quotes: [CanonicalSymbol: Quote] = [:]
    private var bars: [PriceBar] = []

    func portfolioSnapshot() async throws -> PortfolioSnapshot {
        PortfolioSnapshot(
            brokerages: Array(brokerages.values),
            accounts: Array(accounts.values)
        )
    }

    func account(id: AccountID) async throws -> BrokerageAccount? {
        accounts[id]
    }

    func account(sourceKey: SourceAccountKey) async throws -> BrokerageAccount? {
        accounts.values.first { $0.sourceKey == sourceKey }
    }

    func replaceAccount(
        _ snapshot: AccountReplacementSnapshot,
        audit: ImportAuditMetadata
    ) async throws -> AccountID {
        let id = snapshot.accountID ?? AccountID()
        let existing = accounts.values.first { $0.sourceKey == snapshot.sourceKey } ?? accounts[id]
        let enabled = existing?.isEnabled ?? true
        let override = existing?.displayNameOverride
        let resolvedID = existing?.id ?? id
        let slices = try snapshot.slices.map { slice in
            try PositionSlice(
                id: slice.id,
                accountID: resolvedID,
                nativeSymbol: slice.nativeSymbol,
                canonicalSymbol: slice.canonicalSymbol,
                securityName: slice.securityName,
                securityKind: slice.securityKind,
                quantity: slice.quantity,
                unitCost: slice.unitCost,
                acquiredAt: slice.acquiredAt,
                basisKind: slice.basisKind,
                provenance: slice.provenance
            )
        }
        let account = BrokerageAccount(
            id: resolvedID,
            brokerageID: snapshot.brokerageID,
            sourceKey: snapshot.sourceKey,
            sourceDisplayName: snapshot.sourceDisplayName,
            displayNameOverride: override,
            kindHint: snapshot.kindHint,
            cash: snapshot.cash,
            isEnabled: enabled,
            freshness: .current,
            sourceAsOf: snapshot.sourceAsOf,
            lastImportedAt: snapshot.lastImportedAt,
            slices: slices
        )
        accounts[account.id] = account
        brokerages[snapshot.brokerageID] = Brokerage(
            id: snapshot.brokerageID,
            displayName: snapshot.brokerageID.rawValue == "schwab" ? "Charles Schwab" : snapshot.brokerageID.rawValue,
            lastCompleteImportAt: snapshot.lastImportedAt
        )
        for quote in snapshot.importedQuotes {
            quotes[quote.canonicalSymbol] = quote
        }
        _ = audit
        return account.id
    }

    func markMissingAccountsStale(
        brokerageID: BrokerageID,
        presentKeys: [SourceAccountKey],
        asOf: Date
    ) async throws -> [AccountID] {
        let present = Set(presentKeys)
        var marked: [AccountID] = []
        for (id, account) in accounts where account.brokerageID == brokerageID {
            if !present.contains(account.sourceKey) {
                accounts[id] = BrokerageAccount(
                    id: account.id,
                    brokerageID: account.brokerageID,
                    sourceKey: account.sourceKey,
                    sourceDisplayName: account.sourceDisplayName,
                    displayNameOverride: account.displayNameOverride,
                    kindHint: account.kindHint,
                    cash: account.cash,
                    isEnabled: account.isEnabled,
                    freshness: .stale(missingSince: asOf),
                    sourceAsOf: account.sourceAsOf,
                    lastImportedAt: account.lastImportedAt,
                    slices: account.slices
                )
                marked.append(id)
            }
        }
        return marked
    }

    func setAccountEnabled(id: AccountID, enabled: Bool) async throws {
        guard let account = accounts[id] else { return }
        accounts[id] = BrokerageAccount(
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
    }

    func deleteStaleAccount(id: AccountID) async throws {
        guard let account = accounts[id], case .stale = account.freshness else { return }
        accounts[id] = nil
    }

    func cachedQuotes(symbols: [CanonicalSymbol]) async throws -> [CanonicalSymbol: Quote] {
        var result: [CanonicalSymbol: Quote] = [:]
        for symbol in symbols {
            if let quote = quotes[symbol] { result[symbol] = quote }
        }
        return result
    }

    func saveQuotes(_ quotes: [Quote]) async throws {
        for quote in quotes {
            self.quotes[quote.canonicalSymbol] = quote
        }
    }

    func cachedBars(
        symbols: [CanonicalSymbol],
        interval: PriceBarInterval,
        from: Date,
        to: Date
    ) async throws -> [CanonicalSymbol: [PriceBar]] {
        let keys = Set(symbols)
        var result: [CanonicalSymbol: [PriceBar]] = [:]
        for bar in bars where keys.contains(bar.canonicalSymbol)
            && bar.interval == interval
            && bar.timestamp >= from
            && bar.timestamp <= to {
            result[bar.canonicalSymbol, default: []].append(bar)
        }
        return result
    }

    func saveBars(_ bars: [PriceBar]) async throws {
        self.bars.append(contentsOf: bars)
    }
}
