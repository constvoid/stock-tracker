import Domain
import Foundation

public enum HistoryReconstruction {
    /// Reconstruct portfolio/account value series from current slices + price bars + flat cash.
    public static func series(
        slices: [PositionSlice],
        cash: Money,
        barsBySymbol: [CanonicalSymbol: [PriceBar]],
        range: TimeRange,
        quality: HistoryQuality
    ) throws -> HistoricalSeries {
        let timeline = unifiedTimeline(barsBySymbol: barsBySymbol)
        var points: [ValuationPoint] = []

        for timestamp in timeline {
            let heldSlices = slices.filter { isHeld($0, at: timestamp) }
            if heldSlices.isEmpty {
                // Nothing held yet: skip empty pre-acquisition timestamps when cash is zero.
                if cash.amount == 0 { continue }
                points.append(ValuationPoint(timestamp: timestamp, value: cash))
                continue
            }

            var equity = Decimal(0)
            var missingRequiredPrice = false

            for slice in heldSlices {
                if let price = price(
                    for: slice.canonicalSymbol,
                    at: timestamp,
                    barsBySymbol: barsBySymbol
                ) {
                    equity += slice.quantity.shares * price
                } else {
                    missingRequiredPrice = true
                    break
                }
            }

            if missingRequiredPrice {
                // HIST-005: expected-session gap — omit point (chart discontinuity).
                continue
            }

            let total = try Money.usd(equity + cash.amount)
            points.append(ValuationPoint(timestamp: timestamp, value: total))
        }

        let disclosure: String
        switch quality {
        case .reconstructed:
            disclosure = "Reconstructed from current holdings and historical prices. Cash is held flat."
        case .estimatedUnknownAcquisitionDates:
            disclosure = "Estimated: some positions lack acquisition dates and are assumed held for the full range."
        }

        return HistoricalSeries(
            range: range,
            points: points,
            quality: quality,
            disclosure: disclosure,
            asOf: timeline.last
        )
    }

    public static func isHeld(_ slice: PositionSlice, at timestamp: Date) -> Bool {
        switch slice.basisKind {
        case .aggregatePosition:
            return true
        case .exactAcquisition:
            guard let acquiredAt = slice.acquiredAt else { return false }
            return acquiredAt <= timestamp
        }
    }

    /// Resolve price at timestamp with carry-forward across non-trading gaps only.
    public static func price(
        for symbol: CanonicalSymbol,
        at timestamp: Date,
        barsBySymbol: [CanonicalSymbol: [PriceBar]]
    ) -> Decimal? {
        guard let bars = barsBySymbol[symbol]?.sorted(by: { $0.timestamp < $1.timestamp }),
              !bars.isEmpty
        else { return nil }

        if let exact = bars.last(where: { $0.timestamp == timestamp }) {
            return exact.close.amount
        }
        guard let prior = bars.last(where: { $0.timestamp < timestamp }) else {
            return nil
        }
        if USMarketCalendar.onlyNonTradingDaysBetween(prior.timestamp, timestamp) {
            return prior.close.amount
        }
        // Expected trading session(s) intervened without a bar → no carry (gap).
        return nil
    }

    private static func unifiedTimeline(
        barsBySymbol: [CanonicalSymbol: [PriceBar]]
    ) -> [Date] {
        let dates = Set(barsBySymbol.values.flatMap { $0.map(\.timestamp) })
        return dates.sorted()
    }
}
