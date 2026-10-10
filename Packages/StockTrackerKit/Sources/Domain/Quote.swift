import Foundation

public struct Quote: Hashable, Sendable, Codable {
    public let canonicalSymbol: CanonicalSymbol
    public let price: Money
    public let previousClose: Money?
    public let asOf: Date
    public let source: QuoteSource
    public let freshness: QuoteFreshness
    public let session: MarketSession

    public init(
        canonicalSymbol: CanonicalSymbol,
        price: Money,
        previousClose: Money? = nil,
        asOf: Date,
        source: QuoteSource,
        freshness: QuoteFreshness,
        session: MarketSession = .regular
    ) {
        self.canonicalSymbol = canonicalSymbol
        self.price = price
        self.previousClose = previousClose
        self.asOf = asOf
        self.source = source
        self.freshness = freshness
        self.session = session
    }

    public func markingStale() -> Quote {
        Quote(
            canonicalSymbol: canonicalSymbol,
            price: price,
            previousClose: previousClose,
            asOf: asOf,
            source: source,
            freshness: .stale,
            session: session
        )
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

public enum TimeRange: String, Hashable, Sendable, Codable, CaseIterable {
    case day
    case week
    case month
    case ytd
    case oneYear
    case threeYears
    case fiveYears

    public var shortTitle: String {
        switch self {
        case .day: "D"
        case .week: "W"
        case .month: "M"
        case .ytd: "YTD"
        case .oneYear: "1Y"
        case .threeYears: "3Y"
        case .fiveYears: "5Y"
        }
    }

    public var accessibilityTitle: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .ytd: "Year to date"
        case .oneYear: "One year"
        case .threeYears: "Three years"
        case .fiveYears: "Five years"
        }
    }
}
