import Foundation

public struct ValuationPoint: Hashable, Sendable, Codable, Identifiable {
    public var id: Date { timestamp }
    public let timestamp: Date
    public let value: Money

    public init(timestamp: Date, value: Money) {
        self.timestamp = timestamp
        self.value = value
    }
}

public struct HistoricalSeries: Hashable, Sendable, Codable {
    public let range: TimeRange
    public let points: [ValuationPoint]
    public let quality: HistoryQuality
    public let disclosure: String
    public let asOf: Date?

    public init(
        range: TimeRange,
        points: [ValuationPoint],
        quality: HistoryQuality,
        disclosure: String,
        asOf: Date?
    ) {
        self.range = range
        self.points = points
        self.quality = quality
        self.disclosure = disclosure
        self.asOf = asOf
    }
}

public enum HistoryScope: Hashable, Sendable {
    case portfolio
    case account(AccountID)
}
