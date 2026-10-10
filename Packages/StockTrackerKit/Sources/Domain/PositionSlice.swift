import Foundation

public struct PositionSlice: Hashable, Sendable, Codable, Identifiable {
    public let id: PositionSliceID
    public let accountID: AccountID
    public let nativeSymbol: NativeSymbol
    public let canonicalSymbol: CanonicalSymbol
    public let securityName: String?
    public let securityKind: SecurityKind
    public let quantity: Quantity
    public let unitCost: UnitCost
    public let acquiredAt: Date?
    public let basisKind: BasisKind
    public let provenance: ImportProvenance

    public init(
        id: PositionSliceID = PositionSliceID(),
        accountID: AccountID,
        nativeSymbol: NativeSymbol,
        canonicalSymbol: CanonicalSymbol,
        securityName: String? = nil,
        securityKind: SecurityKind,
        quantity: Quantity,
        unitCost: UnitCost,
        acquiredAt: Date?,
        basisKind: BasisKind,
        provenance: ImportProvenance
    ) throws {
        if basisKind == .exactAcquisition, acquiredAt == nil {
            throw DomainValueError.exactAcquisitionRequiresDate
        }
        if basisKind == .aggregatePosition, acquiredAt != nil {
            throw DomainValueError.aggregateMustNotHaveDate
        }
        self.id = id
        self.accountID = accountID
        self.nativeSymbol = nativeSymbol
        self.canonicalSymbol = canonicalSymbol
        self.securityName = securityName
        self.securityKind = securityKind
        self.quantity = quantity
        self.unitCost = unitCost
        self.acquiredAt = acquiredAt
        self.basisKind = basisKind
        self.provenance = provenance
    }

    public var hasKnownAcquisitionDate: Bool {
        acquiredAt != nil
    }
}
