import Application
import Domain
import Foundation
import SwiftData

public actor SwiftDataPortfolioRepository: PortfolioRepository {
    private let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    public static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: PortfolioSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, migrationPlan: PortfolioMigrationPlan.self, configurations: [configuration])
    }

    public func portfolioSnapshot() async throws -> PortfolioSnapshot {
        let context = ModelContext(modelContainer)
        let brokerageRecords = try context.fetch(FetchDescriptor<BrokerageRecord>())
        let brokerages = brokerageRecords.map {
            Brokerage(
                id: BrokerageID($0.id),
                displayName: $0.displayName,
                lastCompleteImportAt: $0.lastCompleteImportAt
            )
        }
        let accountRecords = try context.fetch(FetchDescriptor<AccountRecord>())
        let accounts = try accountRecords.map(RecordMapping.domainAccount(from:))
        return PortfolioSnapshot(brokerages: brokerages, accounts: accounts)
    }

    public func account(id: AccountID) async throws -> BrokerageAccount? {
        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<AccountRecord>(
            predicate: #Predicate { $0.id == id.rawValue }
        )
        descriptor.fetchLimit = 1
        guard let record = try context.fetch(descriptor).first else { return nil }
        return try RecordMapping.domainAccount(from: record)
    }

    public func account(sourceKey: SourceAccountKey) async throws -> BrokerageAccount? {
        let context = ModelContext(modelContainer)
        let brokerageID = sourceKey.brokerageID.rawValue
        let external = sourceKey.externalReference
        let descriptor = FetchDescriptor<AccountRecord>(
            predicate: #Predicate {
                $0.sourceExternalReference == external && $0.brokerage?.id == brokerageID
            }
        )
        guard let record = try context.fetch(descriptor).first else { return nil }
        return try RecordMapping.domainAccount(from: record)
    }

    public func replaceAccount(
        _ snapshot: AccountReplacementSnapshot,
        audit: ImportAuditMetadata
    ) async throws -> AccountID {
        let context = ModelContext(modelContainer)
        let brokerage = try upsertBrokerage(
            id: snapshot.brokerageID,
            displayName: displayName(for: snapshot.brokerageID),
            importedAt: snapshot.lastImportedAt,
            context: context
        )

        let accountID = snapshot.accountID?.rawValue ?? UUID()
        let existing = try fetchAccount(id: accountID, context: context)
            ?? fetchAccount(
                brokerageID: snapshot.brokerageID.rawValue,
                external: snapshot.sourceKey.externalReference,
                context: context
            )

        let record: AccountRecord
        if let existing {
            record = existing
            // Preserve user-owned fields: isEnabled, displayNameOverride
            record.sourceDisplayName = snapshot.sourceDisplayName
            record.kindHint = snapshot.kindHint
            record.cashAmount = snapshot.cash.amount
            record.cashCurrency = snapshot.cash.currency.rawValue
            record.sourceAsOf = snapshot.sourceAsOf
            record.lastImportedAt = snapshot.lastImportedAt
            record.staleSince = nil
            for slice in record.slices {
                context.delete(slice)
            }
            record.slices = []
        } else {
            record = AccountRecord(
                id: accountID,
                sourceExternalReference: snapshot.sourceKey.externalReference,
                sourceDisplayName: snapshot.sourceDisplayName,
                kindHint: snapshot.kindHint,
                cashAmount: snapshot.cash.amount,
                lastImportedAt: snapshot.lastImportedAt
            )
            record.sourceAsOf = snapshot.sourceAsOf
            record.brokerage = brokerage
            context.insert(record)
        }

        for slice in snapshot.slices {
            let sliceRecord = PositionSliceRecord(
                id: slice.id.rawValue,
                nativeSymbol: slice.nativeSymbol.rawValue,
                canonicalSymbol: slice.canonicalSymbol.rawValue,
                securityName: slice.securityName,
                securityKind: slice.securityKind.rawValue,
                quantity: slice.quantity.shares,
                unitCostAmount: slice.unitCost.amountPerShare,
                acquiredAt: slice.acquiredAt,
                basisKind: slice.basisKind.rawValue,
                parserIdentifier: slice.provenance.parserIdentifier,
                parserVersion: slice.provenance.parserVersion,
                sourceRow: slice.provenance.sourceRow,
                importedAt: slice.provenance.importedAt
            )
            sliceRecord.account = record
            context.insert(sliceRecord)
        }

        for quote in snapshot.importedQuotes {
            try upsertQuote(quote, context: context)
        }

        let auditRecord = ImportAuditRecord(
            brokerageID: audit.brokerageID.rawValue,
            originalFilename: audit.originalFilename,
            providerTimestamp: audit.providerTimestamp,
            importedAt: audit.importedAt,
            contentFingerprint: audit.contentFingerprint,
            parserIdentifier: audit.parserIdentifier,
            parserVersion: audit.parserVersion,
            accountCount: audit.accountCount,
            positionCount: audit.positionCount,
            warningCount: audit.warningCount,
            errorCount: audit.errorCount,
            issueCodes: audit.issueCodes
        )
        context.insert(auditRecord)

        try context.save()
        return AccountID(record.id)
    }

    public func markMissingAccountsStale(
        brokerageID: BrokerageID,
        presentKeys: [SourceAccountKey],
        asOf: Date
    ) async throws -> [AccountID] {
        let context = ModelContext(modelContainer)
        let brokerageRaw = brokerageID.rawValue
        let present = Set(presentKeys.map(\.externalReference))
        let accounts = try context.fetch(
            FetchDescriptor<AccountRecord>(
                predicate: #Predicate { $0.brokerage?.id == brokerageRaw }
            )
        )
        var marked: [AccountID] = []
        for account in accounts where !present.contains(account.sourceExternalReference) {
            if account.staleSince == nil {
                account.staleSince = asOf
            }
            marked.append(AccountID(account.id))
        }
        if let brokerage = try fetchBrokerage(id: brokerageRaw, context: context) {
            brokerage.lastCompleteImportAt = asOf
        }
        try context.save()
        return marked
    }

    public func setAccountEnabled(id: AccountID, enabled: Bool) async throws {
        let context = ModelContext(modelContainer)
        guard let record = try fetchAccount(id: id.rawValue, context: context) else { return }
        record.isEnabled = enabled
        try context.save()
    }

    public func deleteStaleAccount(id: AccountID) async throws {
        let context = ModelContext(modelContainer)
        guard let record = try fetchAccount(id: id.rawValue, context: context),
              record.staleSince != nil
        else { return }
        context.delete(record)
        try context.save()
    }

    public func cachedQuotes(symbols: [CanonicalSymbol]) async throws -> [CanonicalSymbol: Quote] {
        let context = ModelContext(modelContainer)
        let keys = Set(symbols.map(\.rawValue))
        let records = try context.fetch(FetchDescriptor<QuoteRecord>())
        var result: [CanonicalSymbol: Quote] = [:]
        for record in records where keys.contains(record.canonicalSymbol) {
            let quote = try RecordMapping.domainQuote(from: record)
            result[quote.canonicalSymbol] = quote
        }
        return result
    }

    public func saveQuotes(_ quotes: [Quote]) async throws {
        let context = ModelContext(modelContainer)
        for quote in quotes {
            try upsertQuote(quote, context: context)
        }
        try context.save()
    }

    // MARK: - Helpers

    private func upsertBrokerage(
        id: BrokerageID,
        displayName: String,
        importedAt: Date,
        context: ModelContext
    ) throws -> BrokerageRecord {
        if let existing = try fetchBrokerage(id: id.rawValue, context: context) {
            existing.displayName = displayName
            existing.lastCompleteImportAt = importedAt
            return existing
        }
        let record = BrokerageRecord(id: id.rawValue, displayName: displayName, lastCompleteImportAt: importedAt)
        context.insert(record)
        return record
    }

    private func upsertQuote(_ quote: Quote, context: ModelContext) throws {
        let symbol = quote.canonicalSymbol.rawValue
        var descriptor = FetchDescriptor<QuoteRecord>(
            predicate: #Predicate { $0.canonicalSymbol == symbol }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.priceAmount = quote.price.amount
            existing.previousCloseAmount = quote.previousClose?.amount
            existing.asOf = quote.asOf
            existing.source = quote.source.rawValue
            existing.freshness = quote.freshness.rawValue
        } else {
            context.insert(
                QuoteRecord(
                    canonicalSymbol: symbol,
                    priceAmount: quote.price.amount,
                    previousCloseAmount: quote.previousClose?.amount,
                    asOf: quote.asOf,
                    source: quote.source.rawValue,
                    freshness: quote.freshness.rawValue
                )
            )
        }
    }

    private func fetchBrokerage(id: String, context: ModelContext) throws -> BrokerageRecord? {
        var descriptor = FetchDescriptor<BrokerageRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchAccount(id: UUID, context: ModelContext) throws -> AccountRecord? {
        var descriptor = FetchDescriptor<AccountRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchAccount(brokerageID: String, external: String, context: ModelContext) throws -> AccountRecord? {
        let descriptor = FetchDescriptor<AccountRecord>(
            predicate: #Predicate {
                $0.sourceExternalReference == external && $0.brokerage?.id == brokerageID
            }
        )
        return try context.fetch(descriptor).first
    }

    private func displayName(for brokerageID: BrokerageID) -> String {
        switch brokerageID.rawValue {
        case "schwab": return "Charles Schwab"
        case "etrade": return "E*TRADE"
        default: return brokerageID.rawValue
        }
    }
}
