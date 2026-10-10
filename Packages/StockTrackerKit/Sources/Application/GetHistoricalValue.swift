import Domain
import Foundation
import PortfolioMath

public struct GetHistoricalValue: Sendable {
    private let repository: any PortfolioRepository
    private let intraday: any IntradayPriceProviding
    private let daily: any HistoricalPriceProviding

    public init(
        repository: any PortfolioRepository,
        intraday: any IntradayPriceProviding,
        daily: any HistoricalPriceProviding
    ) {
        self.repository = repository
        self.intraday = intraday
        self.daily = daily
    }

    public func callAsFunction(
        scope: HistoryScope,
        range: TimeRange,
        now: Date = Date()
    ) async throws -> HistoricalSeries {
        let snapshot = try await repository.portfolioSnapshot()
        let accounts: [BrokerageAccount]
        let cash: Money
        let quality: HistoryQuality

        switch scope {
        case .portfolio:
            accounts = snapshot.accounts.filter(\.isEnabled)
            cash = try accounts.reduce(try Money.zero()) { try $0 + $1.cash }
            quality = CapabilityDerivation.portfolioHistoryQuality(accounts: accounts)
        case .account(let id):
            guard let account = snapshot.accounts.first(where: { $0.id == id }) else {
                return HistoricalSeries(
                    range: range,
                    points: [],
                    quality: .reconstructed,
                    disclosure: "Account not found.",
                    asOf: nil
                )
            }
            accounts = [account]
            cash = account.cash
            quality = CapabilityDerivation.accountCapabilities(slices: account.slices).history
        }

        let slices = accounts.flatMap(\.slices)
        let symbols = Array(Set(slices.map(\.canonicalSymbol)))
        guard !symbols.isEmpty else {
            // Cash-only: flat line at cash.
            let point = ValuationPoint(timestamp: now, value: cash)
            return HistoricalSeries(
                range: range,
                points: [point],
                quality: quality,
                disclosure: quality == .estimatedUnknownAcquisitionDates
                    ? "Estimated cash-only series."
                    : "Cash held flat across the selected range.",
                asOf: now
            )
        }

        let barsBySymbol = try await loadBars(symbols: symbols, range: range, now: now)
        return try HistoryReconstruction.series(
            slices: slices,
            cash: cash,
            barsBySymbol: barsBySymbol,
            range: range,
            quality: quality
        )
    }

    private func loadBars(
        symbols: [CanonicalSymbol],
        range: TimeRange,
        now: Date
    ) async throws -> [CanonicalSymbol: [PriceBar]] {
        let interval: PriceBarInterval = range == .day ? .fiveMinute : .daily
        let windowStart = rangeStart(for: range, now: now)

        let cached = try await repository.cachedBars(
            symbols: symbols,
            interval: interval,
            from: windowStart,
            to: now
        )
        if cached.values.contains(where: { !$0.isEmpty }) {
            // Prefer cache when present; still try to refresh in background-like best effort.
        }

        do {
            let fetched: [CanonicalSymbol: [PriceBar]]
            if range == .day {
                fetched = try await intraday.bars(for: symbols, day: now)
            } else {
                fetched = try await daily.dailyBars(for: symbols, range: range)
            }
            let flat = fetched.values.flatMap { $0 }
            if !flat.isEmpty {
                try await repository.saveBars(flat)
            }
            return fetched.isEmpty ? cached : fetched
        } catch {
            if cached.values.contains(where: { !$0.isEmpty }) {
                return cached
            }
            throw error
        }
    }

    private func rangeStart(for range: TimeRange, now: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        switch range {
        case .day:
            return calendar.startOfDay(for: now)
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .ytd:
            let year = calendar.component(.year, from: now)
            return calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .threeYears:
            return calendar.date(byAdding: .year, value: -3, to: now) ?? now
        case .fiveYears:
            return calendar.date(byAdding: .year, value: -5, to: now) ?? now
        }
    }
}
