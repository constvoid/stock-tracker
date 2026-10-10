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
}

/// Brokerage file import port. Concrete CSV adapters live in Importing.
public protocol BrokerageImporting: Sendable {
    func inspect(files: [URL]) async throws -> [BrokerageImportBatch]
}

/// Latest quote port. Concrete Yahoo-style adapter lives in MarketData.
public protocol QuoteProviding: Sendable {}

/// Five-minute intraday history port.
public protocol IntradayPriceProviding: Sendable {}

/// Daily historical close port.
public protocol HistoricalPriceProviding: Sendable {}
