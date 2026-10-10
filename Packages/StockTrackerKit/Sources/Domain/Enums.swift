import Foundation

public enum SecurityKind: String, Hashable, Sendable, Codable {
    case equity
    case etf
}

public enum BasisKind: String, Hashable, Sendable, Codable {
    case exactAcquisition
    case aggregatePosition
}

public enum AccountFreshness: Hashable, Sendable, Codable {
    case current
    case stale(missingSince: Date)
}

public enum TaxTermCapability: String, Hashable, Sendable, Codable {
    case available
    case unavailableMissingAcquisitionDates
}

public enum HistoryQuality: String, Hashable, Sendable, Codable {
    case reconstructed
    case estimatedUnknownAcquisitionDates
}

public enum LivePricingCapability: String, Hashable, Sendable, Codable {
    case available
    case partialMissingSymbols
}

public struct AccountCapabilities: Hashable, Sendable, Codable {
    public let taxTerm: TaxTermCapability
    public let history: HistoryQuality
    public let livePricing: LivePricingCapability

    public init(
        taxTerm: TaxTermCapability,
        history: HistoryQuality,
        livePricing: LivePricingCapability = .available
    ) {
        self.taxTerm = taxTerm
        self.history = history
        self.livePricing = livePricing
    }
}

public enum QuoteSource: String, Hashable, Sendable, Codable {
    case brokerImport
    case marketProvider
}

public enum QuoteFreshness: String, Hashable, Sendable, Codable {
    case fresh
    case stale
}

public enum PriceBarInterval: String, Hashable, Sendable, Codable {
    case fiveMinute
    case daily
}
