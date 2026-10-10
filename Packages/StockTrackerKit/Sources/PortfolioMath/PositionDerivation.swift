import Domain
import Foundation

/// Derived position for one `(accountID, canonicalSymbol)` group.
public struct DerivedPosition: Hashable, Sendable {
    public let accountID: AccountID
    public let canonicalSymbol: CanonicalSymbol
    public let displaySymbol: NativeSymbol
    public let slices: [PositionSlice]
    public let quantity: Quantity
    public let averageCost: Money
    public let costBasis: Money
    public let currentPrice: Money?
    public let marketValue: Money?
    public let unrealizedGain: Money?
    public let dayChange: Money?
    public let quoteFreshness: QuoteFreshness?

    public init(
        accountID: AccountID,
        canonicalSymbol: CanonicalSymbol,
        displaySymbol: NativeSymbol,
        slices: [PositionSlice],
        quantity: Quantity,
        averageCost: Money,
        costBasis: Money,
        currentPrice: Money?,
        marketValue: Money?,
        unrealizedGain: Money?,
        dayChange: Money?,
        quoteFreshness: QuoteFreshness?
    ) {
        self.accountID = accountID
        self.canonicalSymbol = canonicalSymbol
        self.displaySymbol = displaySymbol
        self.slices = slices
        self.quantity = quantity
        self.averageCost = averageCost
        self.costBasis = costBasis
        self.currentPrice = currentPrice
        self.marketValue = marketValue
        self.unrealizedGain = unrealizedGain
        self.dayChange = dayChange
        self.quoteFreshness = quoteFreshness
    }
}

public enum PositionDerivation {
    public static func positions(
        from slices: [PositionSlice],
        quotes: [CanonicalSymbol: Quote] = [:]
    ) throws -> [DerivedPosition] {
        let grouped = Dictionary(grouping: slices, by: \.canonicalSymbol)
        return try grouped.keys.sorted { $0.rawValue < $1.rawValue }.compactMap { symbol in
            guard let group = grouped[symbol], let first = group.first else { return nil }
            let quantity = try CostBasisMath.totalQuantity(slices: group)
            let costBasis = try CostBasisMath.totalCostBasis(slices: group)
            guard let averageCost = try CostBasisMath.weightedAverageCost(slices: group) else {
                return nil
            }

            let quote = quotes[symbol]
            let currentPrice = quote?.price
            let marketValue: Money?
            let unrealizedGain: Money?
            let dayChange: Money?

            if let currentPrice {
                let mv = try Money(amount: quantity.shares * currentPrice.amount, currency: currentPrice.currency)
                marketValue = mv
                unrealizedGain = try mv - costBasis
                if let previous = quote?.previousClose {
                    let previousValue = try Money(
                        amount: quantity.shares * previous.amount,
                        currency: previous.currency
                    )
                    dayChange = try mv - previousValue
                } else {
                    dayChange = nil
                }
            } else {
                marketValue = nil
                unrealizedGain = nil
                dayChange = nil
            }

            return DerivedPosition(
                accountID: first.accountID,
                canonicalSymbol: symbol,
                displaySymbol: first.nativeSymbol,
                slices: group,
                quantity: quantity,
                averageCost: averageCost,
                costBasis: costBasis,
                currentPrice: currentPrice,
                marketValue: marketValue,
                unrealizedGain: unrealizedGain,
                dayChange: dayChange,
                quoteFreshness: quote?.freshness
            )
        }
    }
}
