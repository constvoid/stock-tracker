import Foundation

public struct Brokerage: Hashable, Sendable, Codable, Identifiable {
    public let id: BrokerageID
    public let displayName: String
    public let lastCompleteImportAt: Date?

    public init(id: BrokerageID, displayName: String, lastCompleteImportAt: Date? = nil) {
        self.id = id
        self.displayName = displayName
        self.lastCompleteImportAt = lastCompleteImportAt
    }
}

public struct BrokerageAccount: Hashable, Sendable, Codable, Identifiable {
    public let id: AccountID
    public let brokerageID: BrokerageID
    public let sourceKey: SourceAccountKey
    public let sourceDisplayName: String
    public let displayNameOverride: String?
    public let kindHint: String?
    public let cash: Money
    public let isEnabled: Bool
    public let freshness: AccountFreshness
    public let sourceAsOf: Date?
    public let lastImportedAt: Date
    public let slices: [PositionSlice]

    public init(
        id: AccountID = AccountID(),
        brokerageID: BrokerageID,
        sourceKey: SourceAccountKey,
        sourceDisplayName: String,
        displayNameOverride: String? = nil,
        kindHint: String? = nil,
        cash: Money,
        isEnabled: Bool = true,
        freshness: AccountFreshness = .current,
        sourceAsOf: Date? = nil,
        lastImportedAt: Date,
        slices: [PositionSlice] = []
    ) {
        self.id = id
        self.brokerageID = brokerageID
        self.sourceKey = sourceKey
        self.sourceDisplayName = sourceDisplayName
        self.displayNameOverride = displayNameOverride
        self.kindHint = kindHint
        self.cash = cash
        self.isEnabled = isEnabled
        self.freshness = freshness
        self.sourceAsOf = sourceAsOf
        self.lastImportedAt = lastImportedAt
        self.slices = slices
    }

    public var displayName: String {
        displayNameOverride ?? sourceDisplayName
    }

    public var isCashOnly: Bool {
        slices.isEmpty
    }
}
