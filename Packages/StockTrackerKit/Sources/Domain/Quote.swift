import Foundation

public struct Quote: Hashable, Sendable, Codable {
    public let canonicalSymbol: CanonicalSymbol
    public let price: Money
    public let previousClose: Money?
    public let asOf: Date
    public let source: QuoteSource
    public let freshness: QuoteFreshness

    public init(
        canonicalSymbol: CanonicalSymbol,
        price: Money,
        previousClose: Money? = nil,
        asOf: Date,
        source: QuoteSource,
        freshness: QuoteFreshness
    ) {
        self.canonicalSymbol = canonicalSymbol
        self.price = price
        self.previousClose = previousClose
        self.asOf = asOf
        self.source = source
        self.freshness = freshness
    }
}

public struct PriceBar: Hashable, Sendable, Codable {
    public let canonicalSymbol: CanonicalSymbol
    public let timestamp: Date
    public let close: Money
    public let interval: PriceBarInterval
    public let source: QuoteSource

    public init(
        canonicalSymbol: CanonicalSymbol,
        timestamp: Date,
        close: Money,
        interval: PriceBarInterval,
        source: QuoteSource = .marketProvider
    ) {
        self.canonicalSymbol = canonicalSymbol
        self.timestamp = timestamp
        self.close = close
        self.interval = interval
        self.source = source
    }
}
