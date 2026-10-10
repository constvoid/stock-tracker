import Domain
import Foundation

/// Portfolio persistence port. Concrete SwiftData adapter lives in Persistence.
public protocol PortfolioRepository: Sendable {
    func portfolioSnapshot() async throws -> PortfolioSnapshot
    func account(id: AccountID) async throws -> BrokerageAccount?
    func account(sourceKey: SourceAccountKey) async throws -> BrokerageAccount?
    func replaceAccount(_ snapshot: AccountReplacementSnapshot, audit: ImportAuditMetadata) async throws -> AccountID
    func markMissingAccountsStale(
        brokerageID: BrokerageID,
        presentKeys: [SourceAccountKey],
        asOf: Date
    ) async throws -> [AccountID]
    func setAccountEnabled(id: AccountID, enabled: Bool) async throws
    func deleteStaleAccount(id: AccountID) async throws
    func cachedQuotes(symbols: [CanonicalSymbol]) async throws -> [CanonicalSymbol: Quote]
    func saveQuotes(_ quotes: [Quote]) async throws
    func cachedBars(
        symbols: [CanonicalSymbol],
        interval: PriceBarInterval,
        from: Date,
        to: Date
    ) async throws -> [CanonicalSymbol: [PriceBar]]
    func saveBars(_ bars: [PriceBar]) async throws
}

/// Brokerage file import port. Concrete CSV adapters live in Importing.
public protocol BrokerageImporting: Sendable {
    func inspect(files: [URL]) async throws -> [BrokerageImportBatch]
}

/// Latest quote port. Concrete Yahoo-style adapter lives in MarketData.
public protocol QuoteProviding: Sendable {
    func quotes(for symbols: [CanonicalSymbol]) async throws -> [CanonicalSymbol: Quote]
}

/// Five-minute intraday history port.
public protocol IntradayPriceProviding: Sendable {
    func bars(for symbols: [CanonicalSymbol], day: Date) async throws -> [CanonicalSymbol: [PriceBar]]
}

/// Daily historical close port.
public protocol HistoricalPriceProviding: Sendable {
    func dailyBars(
        for symbols: [CanonicalSymbol],
        range: TimeRange
    ) async throws -> [CanonicalSymbol: [PriceBar]]
}

public enum MarketDataError: Error, Equatable, Sendable {
    case networkFailure
    case decodingFailure
    case emptyResponse
    case symbolUnavailable(String)
}
