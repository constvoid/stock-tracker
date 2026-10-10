import Domain
import Foundation

public struct MarketRefreshResult: Hashable, Sendable {
    public let updatedSymbols: [CanonicalSymbol]
    public let failed: Bool
    public let usedStaleCache: Bool

    public init(updatedSymbols: [CanonicalSymbol], failed: Bool, usedStaleCache: Bool) {
        self.updatedSymbols = updatedSymbols
        self.failed = failed
        self.usedStaleCache = usedStaleCache
    }
}

/// Refresh quotes from the provider and persist them. Never mutates holdings.
public struct RefreshMarketData: Sendable {
    private let repository: any PortfolioRepository
    private let quoteProvider: any QuoteProviding
    private let freshWindow: TimeInterval

    public init(
        repository: any PortfolioRepository,
        quoteProvider: any QuoteProviding,
        freshWindow: TimeInterval = 15 * 60
    ) {
        self.repository = repository
        self.quoteProvider = quoteProvider
        self.freshWindow = freshWindow
    }

    public func callAsFunction(now: Date = Date()) async -> MarketRefreshResult {
        do {
            let snapshot = try await repository.portfolioSnapshot()
            let symbols = Array(
                Set(snapshot.accounts.filter(\.isEnabled).flatMap(\.slices).map(\.canonicalSymbol))
            )
            guard !symbols.isEmpty else {
                return MarketRefreshResult(updatedSymbols: [], failed: false, usedStaleCache: false)
            }

            let providerQuotes = try await quoteProvider.quotes(for: symbols)
            var toSave: [Quote] = []
            for symbol in symbols {
                if let quote = providerQuotes[symbol] {
                    let freshness: QuoteFreshness =
                        now.timeIntervalSince(quote.asOf) <= freshWindow ? .fresh : .stale
                    toSave.append(
                        Quote(
                            canonicalSymbol: quote.canonicalSymbol,
                            price: quote.price,
                            previousClose: quote.previousClose,
                            asOf: quote.asOf,
                            source: .marketProvider,
                            freshness: freshness,
                            session: quote.session
                        )
                    )
                }
            }
            if !toSave.isEmpty {
                try await repository.saveQuotes(toSave)
            }
            return MarketRefreshResult(
                updatedSymbols: toSave.map(\.canonicalSymbol),
                failed: toSave.count < symbols.count && toSave.isEmpty,
                usedStaleCache: false
            )
        } catch {
            return await markCachedStale()
        }
    }

    private func markCachedStale() async -> MarketRefreshResult {
        do {
            let snapshot = try await repository.portfolioSnapshot()
            let symbols = Array(
                Set(snapshot.accounts.flatMap(\.slices).map(\.canonicalSymbol))
            )
            let cached = try await repository.cachedQuotes(symbols: symbols)
            let stale = cached.values.map { $0.markingStale() }
            if !stale.isEmpty {
                try await repository.saveQuotes(Array(stale))
            }
            // Holdings untouched — only quote freshness changed.
            return MarketRefreshResult(
                updatedSymbols: [],
                failed: true,
                usedStaleCache: !stale.isEmpty
            )
        } catch {
            return MarketRefreshResult(updatedSymbols: [], failed: true, usedStaleCache: false)
        }
    }
}
