import Foundation

public enum CurrencyCode: String, Hashable, Sendable, Codable {
    case usd = "USD"
}

public enum DomainValueError: Error, Equatable, Sendable {
    case nonFinite
    case unsupportedCurrency
    case negativeQuantity
    case zeroQuantity
    case exactAcquisitionRequiresDate
    case aggregateMustNotHaveDate
}

/// Decimal USD amount. Formatting is presentation-only.
public struct Money: Hashable, Sendable, Codable {
    public let amount: Decimal
    public let currency: CurrencyCode

    public init(amount: Decimal, currency: CurrencyCode = .usd) throws {
        guard amount.isFinite else { throw DomainValueError.nonFinite }
        guard currency == .usd else { throw DomainValueError.unsupportedCurrency }
        self.amount = amount
        self.currency = currency
    }

    public static func usd(_ amount: Decimal) throws -> Money {
        try Money(amount: amount, currency: .usd)
    }

    public static func zero(currency: CurrencyCode = .usd) throws -> Money {
        try Money(amount: 0, currency: currency)
    }

    public static func + (lhs: Money, rhs: Money) throws -> Money {
        guard lhs.currency == rhs.currency else { throw DomainValueError.unsupportedCurrency }
        return try Money(amount: lhs.amount + rhs.amount, currency: lhs.currency)
    }

    public static func - (lhs: Money, rhs: Money) throws -> Money {
        guard lhs.currency == rhs.currency else { throw DomainValueError.unsupportedCurrency }
        return try Money(amount: lhs.amount - rhs.amount, currency: lhs.currency)
    }

    public static func * (lhs: Money, rhs: Decimal) throws -> Money {
        try Money(amount: lhs.amount * rhs, currency: lhs.currency)
    }
}

public struct Quantity: Hashable, Sendable, Codable {
    public let shares: Decimal

    public init(shares: Decimal) throws {
        guard shares.isFinite else { throw DomainValueError.nonFinite }
        guard shares >= 0 else { throw DomainValueError.negativeQuantity }
        self.shares = shares
    }

    public var isZero: Bool { shares == 0 }

    public static func + (lhs: Quantity, rhs: Quantity) throws -> Quantity {
        try Quantity(shares: lhs.shares + rhs.shares)
    }
}

public struct UnitCost: Hashable, Sendable, Codable {
    public let amountPerShare: Decimal
    public let currency: CurrencyCode

    public init(amountPerShare: Decimal, currency: CurrencyCode = .usd) throws {
        guard amountPerShare.isFinite else { throw DomainValueError.nonFinite }
        guard currency == .usd else { throw DomainValueError.unsupportedCurrency }
        self.amountPerShare = amountPerShare
        self.currency = currency
    }

    public static func usd(_ amountPerShare: Decimal) throws -> UnitCost {
        try UnitCost(amountPerShare: amountPerShare, currency: .usd)
    }
}

private extension Decimal {
    var isFinite: Bool {
        !isNaN
    }

    /// `Decimal` has no `isNaN` in all overlays — detect via NSDecimalNumber.
    var isNaN: Bool {
        (self as NSDecimalNumber).isEqual(to: NSDecimalNumber.notANumber)
    }
}
