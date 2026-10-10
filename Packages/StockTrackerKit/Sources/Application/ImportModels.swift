import Domain
import Foundation

public struct BrokerageIdentity: Hashable, Sendable, Codable {
    public let id: BrokerageID
    public let displayName: String

    public init(id: BrokerageID, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public enum ImportCoverage: String, Hashable, Sendable, Codable {
    case completeBrokerage
}

public enum ImportIssueSeverity: String, Hashable, Sendable, Codable {
    case warning
    case error
}

public enum ImportIssueScope: String, Hashable, Sendable, Codable {
    case file
    case account
    case row
}

public struct ImportIssue: Hashable, Sendable, Codable {
    public let code: String
    public let severity: ImportIssueSeverity
    public let scope: ImportIssueScope
    public let accountKey: SourceAccountKey?
    public let rowNumber: Int?
    public let redactedMessage: String

    public init(
        code: String,
        severity: ImportIssueSeverity,
        scope: ImportIssueScope,
        accountKey: SourceAccountKey? = nil,
        rowNumber: Int? = nil,
        redactedMessage: String
    ) {
        self.code = code
        self.severity = severity
        self.scope = scope
        self.accountKey = accountKey
        self.rowNumber = rowNumber
        self.redactedMessage = redactedMessage
    }

    public var isBlocking: Bool { severity == .error }
}

public struct ImportSourceMetadata: Hashable, Sendable, Codable {
    public let originalFilename: String
    public let providerTimestamp: Date?
    public let importedAt: Date
    public let contentFingerprint: String
    public let parserIdentifier: String
    public let parserVersion: Int

    public init(
        originalFilename: String,
        providerTimestamp: Date?,
        importedAt: Date,
        contentFingerprint: String,
        parserIdentifier: String,
        parserVersion: Int
    ) {
        self.originalFilename = originalFilename
        self.providerTimestamp = providerTimestamp
        self.importedAt = importedAt
        self.contentFingerprint = contentFingerprint
        self.parserIdentifier = parserIdentifier
        self.parserVersion = parserVersion
    }
}

public struct ImportedPositionSlice: Hashable, Sendable, Codable {
    public let nativeSymbol: String
    public let canonicalSymbolCandidate: String
    public let securityName: String?
    public let securityKind: SecurityKind
    public let quantity: Decimal
    public let importedUnitPrice: Decimal?
    public let importedUnitCost: Decimal
    public let acquiredAt: Date?
    public let basisKind: BasisKind
    public let sourceRow: Int

    public init(
        nativeSymbol: String,
        canonicalSymbolCandidate: String,
        securityName: String?,
        securityKind: SecurityKind,
        quantity: Decimal,
        importedUnitPrice: Decimal?,
        importedUnitCost: Decimal,
        acquiredAt: Date?,
        basisKind: BasisKind,
        sourceRow: Int
    ) {
        self.nativeSymbol = nativeSymbol
        self.canonicalSymbolCandidate = canonicalSymbolCandidate
        self.securityName = securityName
        self.securityKind = securityKind
        self.quantity = quantity
        self.importedUnitPrice = importedUnitPrice
        self.importedUnitCost = importedUnitCost
        self.acquiredAt = acquiredAt
        self.basisKind = basisKind
        self.sourceRow = sourceRow
    }
}

public struct ImportedAccountSnapshot: Hashable, Sendable, Codable {
    public let sourceAccountKey: SourceAccountKey
    public let displayName: String
    public let kindHint: String?
    public let cash: Money
    public let slices: [ImportedPositionSlice]
    public let issues: [ImportIssue]

    public init(
        sourceAccountKey: SourceAccountKey,
        displayName: String,
        kindHint: String? = nil,
        cash: Money,
        slices: [ImportedPositionSlice],
        issues: [ImportIssue] = []
    ) {
        self.sourceAccountKey = sourceAccountKey
        self.displayName = displayName
        self.kindHint = kindHint
        self.cash = cash
        self.slices = slices
        self.issues = issues
    }

    public var hasBlockingIssues: Bool {
        issues.contains(where: \.isBlocking)
    }
}

public struct BrokerageImportBatch: Hashable, Sendable, Codable {
    public let brokerage: BrokerageIdentity
    public let coverage: ImportCoverage
    public let source: ImportSourceMetadata
    public let accounts: [ImportedAccountSnapshot]
    public let issues: [ImportIssue]

    public init(
        brokerage: BrokerageIdentity,
        coverage: ImportCoverage = .completeBrokerage,
        source: ImportSourceMetadata,
        accounts: [ImportedAccountSnapshot],
        issues: [ImportIssue] = []
    ) {
        self.brokerage = brokerage
        self.coverage = coverage
        self.source = source
        self.accounts = accounts
        self.issues = issues
    }

    public var hasFileLevelBlockingIssues: Bool {
        issues.contains { $0.scope == .file && $0.isBlocking }
    }
}

public enum AccountImportDisposition: String, Hashable, Sendable, Codable {
    case new
    case updated
    case unchanged
    case stale
    case blocked
}

public struct AccountImportPreview: Hashable, Sendable, Codable {
    public let sourceAccountKey: SourceAccountKey
    public let displayName: String
    public let disposition: AccountImportDisposition
    public let willCommit: Bool
    public let cash: Money
    public let positionCount: Int
    public let issues: [ImportIssue]
    public let existingAccountID: AccountID?

    public init(
        sourceAccountKey: SourceAccountKey,
        displayName: String,
        disposition: AccountImportDisposition,
        willCommit: Bool,
        cash: Money,
        positionCount: Int,
        issues: [ImportIssue],
        existingAccountID: AccountID?
    ) {
        self.sourceAccountKey = sourceAccountKey
        self.displayName = displayName
        self.disposition = disposition
        self.willCommit = willCommit
        self.cash = cash
        self.positionCount = positionCount
        self.issues = issues
        self.existingAccountID = existingAccountID
    }
}

public struct BrokerageImportPreview: Hashable, Sendable, Codable {
    public let batch: BrokerageImportBatch
    public let accounts: [AccountImportPreview]
    public let staleAccounts: [AccountImportPreview]

    public init(
        batch: BrokerageImportBatch,
        accounts: [AccountImportPreview],
        staleAccounts: [AccountImportPreview]
    ) {
        self.batch = batch
        self.accounts = accounts
        self.staleAccounts = staleAccounts
    }
}

public struct AccountReplacementSnapshot: Hashable, Sendable {
    public let accountID: AccountID?
    public let brokerageID: BrokerageID
    public let sourceKey: SourceAccountKey
    public let sourceDisplayName: String
    public let kindHint: String?
    public let cash: Money
    public let sourceAsOf: Date?
    public let lastImportedAt: Date
    public let slices: [PositionSlice]
    public let importedQuotes: [Quote]

    public init(
        accountID: AccountID?,
        brokerageID: BrokerageID,
        sourceKey: SourceAccountKey,
        sourceDisplayName: String,
        kindHint: String?,
        cash: Money,
        sourceAsOf: Date?,
        lastImportedAt: Date,
        slices: [PositionSlice],
        importedQuotes: [Quote]
    ) {
        self.accountID = accountID
        self.brokerageID = brokerageID
        self.sourceKey = sourceKey
        self.sourceDisplayName = sourceDisplayName
        self.kindHint = kindHint
        self.cash = cash
        self.sourceAsOf = sourceAsOf
        self.lastImportedAt = lastImportedAt
        self.slices = slices
        self.importedQuotes = importedQuotes
    }
}

public struct ImportAuditMetadata: Hashable, Sendable {
    public let brokerageID: BrokerageID
    public let originalFilename: String
    public let providerTimestamp: Date?
    public let importedAt: Date
    public let contentFingerprint: String
    public let parserIdentifier: String
    public let parserVersion: Int
    public let accountCount: Int
    public let positionCount: Int
    public let warningCount: Int
    public let errorCount: Int
    public let issueCodes: [String]

    public init(
        brokerageID: BrokerageID,
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
        self.issueCodes = issueCodes
    }
}

public struct PortfolioSnapshot: Hashable, Sendable {
    public let brokerages: [Brokerage]
    public let accounts: [BrokerageAccount]

    public init(brokerages: [Brokerage], accounts: [BrokerageAccount]) {
        self.brokerages = brokerages
        self.accounts = accounts
    }
}

public struct AccountCommitResult: Hashable, Sendable {
    public let sourceAccountKey: SourceAccountKey
    public let accountID: AccountID?
    public let committed: Bool
    public let issues: [ImportIssue]

    public init(
        sourceAccountKey: SourceAccountKey,
        accountID: AccountID?,
        committed: Bool,
        issues: [ImportIssue]
    ) {
        self.sourceAccountKey = sourceAccountKey
        self.accountID = accountID
        self.committed = committed
        self.issues = issues
    }
}

public struct ImportCommitResult: Hashable, Sendable {
    public let accountResults: [AccountCommitResult]
    public let staleAccountIDs: [AccountID]

    public init(accountResults: [AccountCommitResult], staleAccountIDs: [AccountID]) {
        self.accountResults = accountResults
        self.staleAccountIDs = staleAccountIDs
    }
}
