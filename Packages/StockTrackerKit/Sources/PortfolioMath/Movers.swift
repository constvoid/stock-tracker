import Domain
import Foundation

public struct MoverRow: Hashable, Sendable {
    public let canonicalSymbol: CanonicalSymbol
    public let displaySymbol: NativeSymbol
    public let dayChange: Money
    public let dayChangePercent: Decimal
    public let marketValue: Money

    public init(
        canonicalSymbol: CanonicalSymbol,
        displaySymbol: NativeSymbol,
        dayChange: Money,
        dayChangePercent: Decimal,
        marketValue: Money
    ) {
        self.canonicalSymbol = canonicalSymbol
        self.displaySymbol = displaySymbol
        self.dayChange = dayChange
        self.dayChangePercent = dayChangePercent
        self.marketValue = marketValue
    }
}

public struct Movers: Hashable, Sendable {
    public let gainers: [MoverRow]
    public let losers: [MoverRow]

    public init(gainers: [MoverRow], losers: [MoverRow]) {
        self.gainers = gainers
        self.losers = losers
    }
}

public enum MoversMath {
    public static func movers(
        holdings: [PortfolioHolding],
        limit: Int = 5
    ) -> Movers {
        let ranked = holdings.compactMap { holding -> MoverRow? in
            guard let dayChange = holding.dayChange,
                  let marketValue = holding.marketValue,
                  let price = holding.currentPrice,
                  let previousImplied = previousValue(holding: holding)
            else { return nil }
            let percent: Decimal
            if previousImplied == 0 {
                percent = 0
            } else {
                percent = dayChange.amount / previousImplied
            }
            _ = price
            return MoverRow(
                canonicalSymbol: holding.canonicalSymbol,
                displaySymbol: holding.displaySymbol,
                dayChange: dayChange,
                dayChangePercent: percent,
                marketValue: marketValue
            )
        }

        let gainers = ranked
            .filter { $0.dayChange.amount > 0 }
            .sorted { $0.dayChange.amount > $1.dayChange.amount }
            .prefix(limit)
        let losers = ranked
            .filter { $0.dayChange.amount < 0 }
            .sorted { $0.dayChange.amount < $1.dayChange.amount }
            .prefix(limit)
        return Movers(gainers: Array(gainers), losers: Array(losers))
    }

    private static func previousValue(holding: PortfolioHolding) -> Decimal? {
        guard let marketValue = holding.marketValue?.amount,
              let dayChange = holding.dayChange?.amount
        else { return nil }
        return marketValue - dayChange
    }
}
