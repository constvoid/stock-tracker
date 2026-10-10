import Domain
import Foundation

public enum ImportMapping {
    public static func domainSlices(
        from imported: [ImportedPositionSlice],
        accountID: AccountID,
        provenance: ImportProvenance
    ) throws -> [PositionSlice] {
        try imported.map { slice in
            try PositionSlice(
                accountID: accountID,
                nativeSymbol: NativeSymbol(slice.nativeSymbol),
                canonicalSymbol: CanonicalSymbol(slice.canonicalSymbolCandidate),
                securityName: slice.securityName,
                securityKind: slice.securityKind,
                quantity: Quantity(shares: slice.quantity),
                unitCost: UnitCost.usd(slice.importedUnitCost),
                acquiredAt: slice.acquiredAt,
                basisKind: slice.basisKind,
                provenance: ImportProvenance(
                    parserIdentifier: provenance.parserIdentifier,
                    parserVersion: provenance.parserVersion,
                    sourceRow: slice.sourceRow,
                    importedAt: provenance.importedAt
                )
            )
        }
    }

    public static func importedQuotes(
        from account: ImportedAccountSnapshot,
        asOf: Date
    ) throws -> [Quote] {
        var quotes: [CanonicalSymbol: Quote] = [:]
        for slice in account.slices {
            guard let price = slice.importedUnitPrice else { continue }
            let symbol = CanonicalSymbol(slice.canonicalSymbolCandidate)
            quotes[symbol] = Quote(
                canonicalSymbol: symbol,
                price: try Money.usd(price),
                previousClose: nil,
                asOf: asOf,
                source: .brokerImport,
                freshness: .fresh
            )
        }
        return Array(quotes.values)
    }

    public static func replacementSnapshot(
        from account: ImportedAccountSnapshot,
        brokerage: BrokerageIdentity,
        source: ImportSourceMetadata,
        existingAccountID: AccountID?
    ) throws -> AccountReplacementSnapshot {
        let accountID = existingAccountID ?? AccountID()
        let provenance = ImportProvenance(
            parserIdentifier: source.parserIdentifier,
            parserVersion: source.parserVersion,
            importedAt: source.importedAt
        )
        let slices = try domainSlices(
            from: account.slices,
            accountID: accountID,
            provenance: provenance
        )
        let quotes = try importedQuotes(
            from: account,
            asOf: source.providerTimestamp ?? source.importedAt
        )
        return AccountReplacementSnapshot(
            accountID: accountID,
            brokerageID: brokerage.id,
            sourceKey: account.sourceAccountKey,
            sourceDisplayName: account.displayName,
            kindHint: account.kindHint,
            cash: account.cash,
            sourceAsOf: source.providerTimestamp,
            lastImportedAt: source.importedAt,
            slices: slices,
            importedQuotes: quotes
        )
    }
}
