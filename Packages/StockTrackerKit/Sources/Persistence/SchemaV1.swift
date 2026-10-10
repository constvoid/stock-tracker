import Foundation
import SwiftData

public enum PortfolioSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            BrokerageRecord.self,
            AccountRecord.self,
            PositionSliceRecord.self,
            QuoteRecord.self,
            ImportAuditRecord.self,
        ]
    }
}

public enum PortfolioMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [PortfolioSchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}

@Model
public final class BrokerageRecord {
    @Attribute(.unique) public var id: String
    public var displayName: String
    public var lastCompleteImportAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \AccountRecord.brokerage)
    public var accounts: [AccountRecord]

    public init(id: String, displayName: String, lastCompleteImportAt: Date? = nil) {
        self.id = id
        self.displayName = displayName
        self.lastCompleteImportAt = lastCompleteImportAt
        self.accounts = []
    }
}

@Model
public final class AccountRecord {
    @Attribute(.unique) public var id: UUID
    public var sourceExternalReference: String
    public var sourceDisplayName: String
    public var displayNameOverride: String?
    public var kindHint: String?
    public var cashAmount: Decimal
    public var cashCurrency: String
    public var isEnabled: Bool
    public var staleSince: Date?
    public var sourceAsOf: Date?
    public var lastImportedAt: Date

    public var brokerage: BrokerageRecord?

    @Relationship(deleteRule: .cascade, inverse: \PositionSliceRecord.account)
    public var slices: [PositionSliceRecord]

    public init(
        id: UUID,
        sourceExternalReference: String,
        sourceDisplayName: String,
        displayNameOverride: String? = nil,
        kindHint: String? = nil,
        cashAmount: Decimal,
        cashCurrency: String = "USD",
        isEnabled: Bool = true,
        staleSince: Date? = nil,
        sourceAsOf: Date? = nil,
        lastImportedAt: Date
    ) {
        self.id = id
        self.sourceExternalReference = sourceExternalReference
        self.sourceDisplayName = sourceDisplayName
        self.displayNameOverride = displayNameOverride
        self.kindHint = kindHint
        self.cashAmount = cashAmount
        self.cashCurrency = cashCurrency
        self.isEnabled = isEnabled
        self.staleSince = staleSince
        self.sourceAsOf = sourceAsOf
        self.lastImportedAt = lastImportedAt
        self.slices = []
    }
}

@Model
public final class PositionSliceRecord {
    @Attribute(.unique) public var id: UUID
    public var nativeSymbol: String
    public var canonicalSymbol: String
    public var securityName: String?
    public var securityKind: String
    public var quantity: Decimal
    public var unitCostAmount: Decimal
    public var unitCostCurrency: String
    public var acquiredAt: Date?
    public var basisKind: String
    public var parserIdentifier: String
    public var parserVersion: Int
    public var sourceRow: Int?
    public var importedAt: Date

    public var account: AccountRecord?

    public init(
        id: UUID,
        nativeSymbol: String,
        canonicalSymbol: String,
        securityName: String?,
        securityKind: String,
        quantity: Decimal,
        unitCostAmount: Decimal,
        unitCostCurrency: String = "USD",
        acquiredAt: Date?,
        basisKind: String,
        parserIdentifier: String,
        parserVersion: Int,
        sourceRow: Int?,
        importedAt: Date
    ) {
        self.id = id
        self.nativeSymbol = nativeSymbol
        self.canonicalSymbol = canonicalSymbol
        self.securityName = securityName
        self.securityKind = securityKind
        self.quantity = quantity
        self.unitCostAmount = unitCostAmount
        self.unitCostCurrency = unitCostCurrency
        self.acquiredAt = acquiredAt
        self.basisKind = basisKind
        self.parserIdentifier = parserIdentifier
        self.parserVersion = parserVersion
        self.sourceRow = sourceRow
        self.importedAt = importedAt
    }
}

@Model
public final class QuoteRecord {
    @Attribute(.unique) public var canonicalSymbol: String
    public var priceAmount: Decimal
    public var priceCurrency: String
    public var previousCloseAmount: Decimal?
    public var previousCloseCurrency: String?
    public var asOf: Date
    public var source: String
    public var freshness: String

    public init(
        canonicalSymbol: String,
        priceAmount: Decimal,
        priceCurrency: String = "USD",
        previousCloseAmount: Decimal? = nil,
        previousCloseCurrency: String? = nil,
        asOf: Date,
        source: String,
        freshness: String
    ) {
        self.canonicalSymbol = canonicalSymbol
        self.priceAmount = priceAmount
        self.priceCurrency = priceCurrency
        self.previousCloseAmount = previousCloseAmount
        self.previousCloseCurrency = previousCloseCurrency
        self.asOf = asOf
        self.source = source
        self.freshness = freshness
    }
}

@Model
public final class ImportAuditRecord {
    @Attribute(.unique) public var id: UUID
    public var brokerageID: String
    public var originalFilename: String
    public var providerTimestamp: Date?
    public var importedAt: Date
    public var contentFingerprint: String
    public var parserIdentifier: String
    public var parserVersion: Int
    public var accountCount: Int
    public var positionCount: Int
    public var warningCount: Int
    public var errorCount: Int
    public var issueCodesCSV: String

    public init(
        id: UUID = UUID(),
        brokerageID: String,
        originalFilename: String,
        providerTimestamp: Date?,
        importedAt: Date,
        contentFingerprint: String,
        parserIdentifier: String,
        parserVersion: Int,
        accountCount: Int,
        positionCount: Int,
        warningCount: Int,
        errorCount: Int,
        issueCodes: [String]
    ) {
        self.id = id
        self.brokerageID = brokerageID
        self.originalFilename = originalFilename
        self.providerTimestamp = providerTimestamp
        self.importedAt = importedAt
        self.contentFingerprint = contentFingerprint
        self.parserIdentifier = parserIdentifier
        self.parserVersion = parserVersion
        self.accountCount = accountCount
        self.positionCount = positionCount
        self.warningCount = warningCount
        self.errorCount = errorCount
        self.issueCodesCSV = issueCodes.joined(separator: ",")
    }
}
