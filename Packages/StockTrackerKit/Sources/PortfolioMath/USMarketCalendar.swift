import Foundation

/// Minimal US equity calendar for HIST-005 gap rules (weekends + fixed holidays).
public enum USMarketCalendar {
    public static func makeNYCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        return calendar
    }

    public static func isTradingDay(_ date: Date, calendar: Calendar? = nil) -> Bool {
        let calendar = calendar ?? makeNYCalendar()
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 { return false }
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        let d = calendar.component(.day, from: date)
        return !fixedHolidays(year: y).contains { $0.month == m && $0.day == d }
    }

    public static func onlyNonTradingDaysBetween(
        _ start: Date,
        _ end: Date,
        calendar: Calendar? = nil
    ) -> Bool {
        let calendar = calendar ?? makeNYCalendar()
        guard end > start else { return true }
        var cursor = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        while cursor < endDay {
            if isTradingDay(cursor, calendar: calendar) {
                return false
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? endDay
        }
        return true
    }

    private static func fixedHolidays(year: Int) -> [(month: Int, day: Int)] {
        // Observed fixed-date holidays used for v1 gap classification.
        // Floating holidays are approximated conservatively via weekends only.
        [
            (1, 1),   // New Year's Day
            (6, 19),  // Juneteenth
            (7, 4),   // Independence Day
            (12, 25), // Christmas
        ]
    }
}
