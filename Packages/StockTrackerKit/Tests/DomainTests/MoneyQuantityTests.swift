import Domain
import Foundation
import Testing

@Test("DATA-002 Money rejects non-finite amounts")
func moneyRejectsNonFinite() {
    #expect(throws: DomainValueError.nonFinite) {
        _ = try Money(amount: Decimal.nan)
    }
}

@Test("DATA-002 Quantity rejects negatives")
func quantityRejectsNegative() {
    #expect(throws: DomainValueError.negativeQuantity) {
        _ = try Quantity(shares: -1)
    }
}

@Test("IMP-003 exact acquisition requires date")
func exactAcquisitionRequiresDate() throws {
    let accountID = AccountID()
    let provenance = ImportProvenance(
        parserIdentifier: "fixture",
        parserVersion: 1,
        importedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    #expect(throws: DomainValueError.exactAcquisitionRequiresDate) {
        _ = try PositionSlice(
            accountID: accountID,
            nativeSymbol: NativeSymbol("AAAX"),
            canonicalSymbol: CanonicalSymbol("AAAX"),
            securityKind: .equity,
            quantity: Quantity(shares: 1),
            unitCost: UnitCost.usd(10),
            acquiredAt: nil,
            basisKind: .exactAcquisition,
            provenance: provenance
        )
    }
}

@Test("IMP-003 aggregate must not invent acquisition date")
func aggregateRejectsDate() throws {
    let accountID = AccountID()
    let provenance = ImportProvenance(
        parserIdentifier: "fixture",
        parserVersion: 1,
        importedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    #expect(throws: DomainValueError.aggregateMustNotHaveDate) {
        _ = try PositionSlice(
            accountID: accountID,
            nativeSymbol: NativeSymbol("AAAX"),
            canonicalSymbol: CanonicalSymbol("AAAX"),
            securityKind: .equity,
            quantity: Quantity(shares: 1),
            unitCost: UnitCost.usd(10),
            acquiredAt: Date(timeIntervalSince1970: 1_600_000_000),
            basisKind: .aggregatePosition,
            provenance: provenance
        )
    }
}

private extension Decimal {
    static var nan: Decimal {
        Decimal(string: "NaN") ?? (NSDecimalNumber.notANumber as Decimal)
    }
}
