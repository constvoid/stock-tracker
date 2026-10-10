import Domain
import Foundation
import PortfolioMath
import Testing

@Test("HIST-002 / HIST-003 reconstruct with estimated unknown dates")
func reconstructEstimatedSeries() throws {
    let accountID = AccountID()
    let symbol = CanonicalSymbol("AAAX")
    let provenance = ImportProvenance(
        parserIdentifier: "test",
        parserVersion: 1,
        importedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let slice = try PositionSlice(
        accountID: accountID,
        nativeSymbol: NativeSymbol("AAAX"),
        canonicalSymbol: symbol,
        securityKind: .equity,
        quantity: Quantity(shares: 2),
        unitCost: UnitCost.usd(50),
        acquiredAt: nil,
        basisKind: .aggregatePosition,
        provenance: provenance
    )

    let day1 = date(2026, 1, 2) // Friday
    let day2 = date(2026, 1, 5) // Monday
    let bars = [
        try bar(symbol, day1, 10),
        try bar(symbol, day2, 12),
    ]
    let series = try HistoryReconstruction.series(
        slices: [slice],
        cash: try Money.usd(100),
        barsBySymbol: [symbol: bars],
        range: .week,
        quality: .estimatedUnknownAcquisitionDates
    )
    #expect(series.points.count == 2)
    #expect(series.points[0].value.amount == 120) // 2*10 + 100
    #expect(series.points[1].value.amount == 124) // 2*12 + 100
    #expect(series.quality == .estimatedUnknownAcquisitionDates)
}

@Test("HIST-005 carry across weekend; gap on missing trading day")
func carryWeekendAndGapMissingSession() throws {
    let symbol = CanonicalSymbol("AAAX")
    let friday = date(2026, 1, 2)
    let monday = date(2026, 1, 5)
    let wednesday = date(2026, 1, 7)

    // Price lookup: Monday can carry from Friday (weekend only between).
    #expect(
        HistoryReconstruction.price(
            for: symbol,
            at: monday,
            barsBySymbol: [symbol: [try bar(symbol, friday, 10)]]
        ) == 10
    )

    // Tuesday missing between Friday and Wednesday → no carry to Wednesday from Friday.
    #expect(
        HistoryReconstruction.price(
            for: symbol,
            at: wednesday,
            barsBySymbol: [symbol: [try bar(symbol, friday, 10)]]
        ) == nil
    )

    #expect(USMarketCalendar.isTradingDay(friday))
    #expect(!USMarketCalendar.isTradingDay(date(2026, 1, 3))) // Saturday
    #expect(USMarketCalendar.onlyNonTradingDaysBetween(friday, monday))
}

@Test("HIST-002 exact acquisition excludes pre-buy timestamps")
func exactAcquisitionGatesHold() throws {
    let accountID = AccountID()
    let symbol = CanonicalSymbol("AAAX")
    let acquired = date(2026, 1, 5)
    let slice = try PositionSlice(
        accountID: accountID,
        nativeSymbol: NativeSymbol("AAAX"),
        canonicalSymbol: symbol,
        securityKind: .equity,
        quantity: Quantity(shares: 1),
        unitCost: UnitCost.usd(10),
        acquiredAt: acquired,
        basisKind: .exactAcquisition,
        provenance: ImportProvenance(
            parserIdentifier: "test",
            parserVersion: 1,
            importedAt: date(2026, 1, 10)
        )
    )
    let bars = [
        try bar(symbol, date(2026, 1, 2), 8),
        try bar(symbol, date(2026, 1, 5), 9),
        try bar(symbol, date(2026, 1, 6), 11),
    ]
    let series = try HistoryReconstruction.series(
        slices: [slice],
        cash: try Money.usd(0),
        barsBySymbol: [symbol: bars],
        range: .week,
        quality: .reconstructed
    )
    // Jan 2 excluded (not held); Jan 5 and 6 included.
    #expect(series.points.count == 2)
    #expect(series.points[0].value.amount == 9)
    #expect(series.points[1].value.amount == 11)
}

private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 16))!
}

private func bar(_ symbol: CanonicalSymbol, _ date: Date, _ close: Decimal) throws -> PriceBar {
    PriceBar(
        canonicalSymbol: symbol,
        timestamp: date,
        close: try Money.usd(close),
        interval: .daily
    )
}
