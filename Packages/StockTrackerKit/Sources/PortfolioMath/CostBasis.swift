import Domain
import Foundation

public enum CostBasisMath {
    /// `quantity × unitCost` for a single slice (CALC-001).
    public static func costBasis(of slice: PositionSlice) throws -> Money {
        try Money(
            amount: slice.quantity.shares * slice.unitCost.amountPerShare,
            currency: slice.unitCost.currency
        )
    }

    /// Quantity-weighted average cost across slices (CALC-001).
    public static func weightedAverageCost(slices: [PositionSlice]) throws -> Money? {
        guard !slices.isEmpty else { return nil }
        var totalQuantity = Decimal(0)
        var totalCost = Decimal(0)
        var currency = CurrencyCode.usd

        for slice in slices {
            totalQuantity += slice.quantity.shares
            totalCost += slice.quantity.shares * slice.unitCost.amountPerShare
            currency = slice.unitCost.currency
        }

        guard totalQuantity > 0 else { throw DomainValueError.zeroQuantity }
        return try Money(amount: totalCost / totalQuantity, currency: currency)
    }

    public static func totalCostBasis(slices: [PositionSlice]) throws -> Money {
        var total = try Money.zero()
        for slice in slices {
            total = try total + costBasis(of: slice)
        }
        return total
    }

    public static func totalQuantity(slices: [PositionSlice]) throws -> Quantity {
        var total = try Quantity(shares: 0)
        for slice in slices {
            total = try total + slice.quantity
        }
        return total
    }
}
