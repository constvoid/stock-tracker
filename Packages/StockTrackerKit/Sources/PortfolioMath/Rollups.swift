import Domain
import Foundation

public struct AccountRollup: Hashable, Sendable {
    public let accountID: AccountID
    public let equityValue: Money
    public let cash: Money
    public let totalValue: Money
    public let positions: [DerivedPosition]

    public init(
        accountID: AccountID,
        equityValue: Money,
        cash: Money,
        totalValue: Money,
        positions: [DerivedPosition]
    ) {
        self.accountID = accountID
        self.equityValue = equityValue
        self.cash = cash
        self.totalValue = totalValue
        self.positions = positions
    }
}

public struct PortfolioHolding: Hashable, Sendable {
    public let canonicalSymbol: CanonicalSymbol
    public let displaySymbol: NativeSymbol
    public let quantity: Quantity
    public let averageCost: Money
    public let costBasis: Money
    public let currentPrice: Money?
    public let marketValue: Money?
    public let dayChange: Money?
    public let accountAllocations: [AccountID: Quantity]

    public init(
        canonicalSymbol: CanonicalSymbol,
        displaySymbol: NativeSymbol,
        quantity: Quantity,
        averageCost: Money,
        costBasis: Money,
        currentPrice: Money?,
        marketValue: Money?,
        dayChange: Money?,
        accountAllocations: [AccountID: Quantity]
    ) {
        self.canonicalSymbol = canonicalSymbol
        self.displaySymbol = displaySymbol
        self.quantity = quantity
        self.averageCost = averageCost
        self.costBasis = costBasis
        self.currentPrice = currentPrice
        self.marketValue = marketValue
        self.dayChange = dayChange
        self.accountAllocations = accountAllocations
    }
}

public struct PortfolioRollup: Hashable, Sendable {
    public let totalValue: Money
    public let equityValue: Money
    public let cashValue: Money
    public let accountRollups: [AccountRollup]
    public let holdings: [PortfolioHolding]

    public init(
        totalValue: Money,
        equityValue: Money,
        cashValue: Money,
        accountRollups: [AccountRollup],
        holdings: [PortfolioHolding]
    ) {
        self.totalValue = totalValue
        self.equityValue = equityValue
        self.cashValue = cashValue
        self.accountRollups = accountRollups
        self.holdings = holdings
    }
}

public enum RollupMath {
    /// CALC-002: account value = equity market value + cash.
    public static func accountRollup(
        account: BrokerageAccount,
        quotes: [CanonicalSymbol: Quote] = [:]
    ) throws -> AccountRollup {
        let positions = try PositionDerivation.positions(from: account.slices, quotes: quotes)
        var equity = try Money.zero()
        for position in positions {
            if let marketValue = position.marketValue {
                equity = try equity + marketValue
            }
        }
        let total = try equity + account.cash
        return AccountRollup(
            accountID: account.id,
            equityValue: equity,
            cash: account.cash,
            totalValue: total,
            positions: positions
        )
    }

    /// CALC-002 / CALC-003: enabled accounts only; duplicate symbols aggregate.
    public static func portfolioRollup(
        accounts: [BrokerageAccount],
        quotes: [CanonicalSymbol: Quote] = [:]
    ) throws -> PortfolioRollup {
        let enabled = accounts.filter(\.isEnabled)
        let accountRollups = try enabled.map { try accountRollup(account: $0, quotes: quotes) }

        var equity = try Money.zero()
        var cash = try Money.zero()
        for rollup in accountRollups {
            equity = try equity + rollup.equityValue
            cash = try cash + rollup.cash
        }

        let allSlices = enabled.flatMap(\.slices)
        let holdings = try aggregateHoldings(slices: allSlices, quotes: quotes)

        return PortfolioRollup(
            totalValue: try equity + cash,
            equityValue: equity,
            cashValue: cash,
            accountRollups: accountRollups,
            holdings: holdings
        )
    }

    public static func aggregateHoldings(
        slices: [PositionSlice],
        quotes: [CanonicalSymbol: Quote] = [:]
    ) throws -> [PortfolioHolding] {
        let bySymbol = Dictionary(grouping: slices, by: \.canonicalSymbol)
        return try bySymbol.keys.sorted { $0.rawValue < $1.rawValue }.compactMap { symbol in
            guard let group = bySymbol[symbol], let first = group.first else { return nil }
            let quantity = try CostBasisMath.totalQuantity(slices: group)
            let costBasis = try CostBasisMath.totalCostBasis(slices: group)
            guard let averageCost = try CostBasisMath.weightedAverageCost(slices: group) else {
                return nil
            }

            var allocations: [AccountID: Quantity] = [:]
            for accountGroup in Dictionary(grouping: group, by: \.accountID) {
                allocations[accountGroup.key] = try CostBasisMath.totalQuantity(slices: accountGroup.value)
            }

            let quote = quotes[symbol]
            let currentPrice = quote?.price
            let marketValue: Money?
            let dayChange: Money?
            if let currentPrice {
                let mv = try Money(amount: quantity.shares * currentPrice.amount, currency: currentPrice.currency)
                marketValue = mv
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
                dayChange = nil
            }

            return PortfolioHolding(
                canonicalSymbol: symbol,
                displaySymbol: first.nativeSymbol,
                quantity: quantity,
                averageCost: averageCost,
                costBasis: costBasis,
                currentPrice: currentPrice,
                marketValue: marketValue,
                dayChange: dayChange,
                accountAllocations: allocations
            )
        }
    }
}
