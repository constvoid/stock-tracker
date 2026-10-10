import Application
import Domain
import Foundation

/// Deterministic quote provider for tests and offline demos.
public struct FakeQuoteProvider: QuoteProviding {
    public var quotesBySymbol: [CanonicalSymbol: Quote]
    public var shouldFail: Bool

    public init(quotesBySymbol: [CanonicalSymbol: Quote] = [:], shouldFail: Bool = false) {
        self.quotesBySymbol = quotesBySymbol
        self.shouldFail = shouldFail
    }

    public func quotes(for symbols: [CanonicalSymbol]) async throws -> [CanonicalSymbol: Quote] {
        if shouldFail { throw MarketDataError.networkFailure }
        var result: [CanonicalSymbol: Quote] = [:]
        for symbol in symbols {
            if let quote = quotesBySymbol[symbol] {
                result[symbol] = quote
            }
        }
        return result
    }
}
