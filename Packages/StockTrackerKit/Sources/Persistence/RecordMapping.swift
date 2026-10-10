import Domain
import Foundation

enum RecordMapping {
    static func domainAccount(from record: AccountRecord) throws -> BrokerageAccount {
        guard let brokerage = record.brokerage else {
            throw PersistenceError.missingBrokerageRelation
        }
        let freshness: AccountFreshness
        if let staleSince = record.staleSince {
            freshness = .stale(missingSince: staleSince)
        } else {
            freshness = .current
        }
        let slices = try record.slices.map(domainSlice(from:))
        return BrokerageAccount(
            id: AccountID(record.id),
            brokerageID: BrokerageID(brokerage.id),
            sourceKey: SourceAccountKey(
                brokerageID: BrokerageID(brokerage.id),
                externalReference: record.sourceExternalReference
            ),
            sourceDisplayName: record.sourceDisplayName,
            displayNameOverride: record.displayNameOverride,
            kindHint: record.kindHint,
            cash: try Money(amount: record.cashAmount, currency: .usd),
            isEnabled: record.isEnabled,
            freshness: freshness,
            sourceAsOf: record.sourceAsOf,
            lastImportedAt: record.lastImportedAt,
            slices: slices
        )
    }

    static func domainSlice(from record: PositionSliceRecord) throws -> PositionSlice {
        guard let account = record.account else {
            throw PersistenceError.missingAccountRelation
        }
        guard let kind = SecurityKind(rawValue: record.securityKind),
              let basis = BasisKind(rawValue: record.basisKind)
        else {
            throw PersistenceError.invalidStoredEnum
        }
        return try PositionSlice(
            id: PositionSliceID(record.id),
            accountID: AccountID(account.id),
            nativeSymbol: NativeSymbol(record.nativeSymbol),
            canonicalSymbol: CanonicalSymbol(record.canonicalSymbol),
            securityName: record.securityName,
            securityKind: kind,
            quantity: Quantity(shares: record.quantity),
            unitCost: UnitCost(amountPerShare: record.unitCostAmount, currency: .usd),
            acquiredAt: record.acquiredAt,
            basisKind: basis,
            provenance: ImportProvenance(
                parserIdentifier: record.parserIdentifier,
                parserVersion: record.parserVersion,
                sourceRow: record.sourceRow,
                importedAt: record.importedAt
            )
        )
    }

    static func domainQuote(from record: QuoteRecord) throws -> Quote {
        guard let source = QuoteSource(rawValue: record.source),
              let freshness = QuoteFreshness(rawValue: record.freshness)
        else {
            throw PersistenceError.invalidStoredEnum
        }
        let previous: Money?
        if let amount = record.previousCloseAmount {
            previous = try Money(amount: amount, currency: .usd)
        } else {
            previous = nil
        }
        return Quote(
            canonicalSymbol: CanonicalSymbol(record.canonicalSymbol),
            price: try Money(amount: record.priceAmount, currency: .usd),
            previousClose: previous,
            asOf: record.asOf,
            source: source,
            freshness: freshness
        )
    }
}

public enum PersistenceError: Error, Equatable, Sendable {
    case missingBrokerageRelation
    case missingAccountRelation
    case invalidStoredEnum
}
