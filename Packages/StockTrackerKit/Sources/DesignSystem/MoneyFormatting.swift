import Foundation

public enum MoneyFormatting {
    private static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = .current
        return formatter
    }()

    private static let compactCurrency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = .current
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let percent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = .current
        return formatter
    }()

    private static let quantity: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.locale = .current
        return formatter
    }()

    public static func currency(_ amount: Decimal, compact: Bool = false) -> String {
        let number = amount as NSDecimalNumber
        return (compact ? compactCurrency : currency).string(from: number) ?? "$0.00"
    }

    public static func signedCurrency(_ amount: Decimal) -> String {
        let formatted = currency(amount)
        if amount > 0 { return "+\(formatted)" }
        return formatted
    }

    public static func percent(_ ratio: Decimal) -> String {
        let number = ratio as NSDecimalNumber
        return percent.string(from: number) ?? "0%"
    }

    public static func signedPercent(_ ratio: Decimal) -> String {
        let formatted = percent(ratio)
        if ratio > 0 { return "+\(formatted)" }
        return formatted
    }

    public static func shares(_ amount: Decimal) -> String {
        let number = amount as NSDecimalNumber
        return quantity.string(from: number) ?? "0"
    }
}
