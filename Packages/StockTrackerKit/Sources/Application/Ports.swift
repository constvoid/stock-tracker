import Domain
import Foundation

/// Portfolio persistence port. Concrete SwiftData adapter lives in Persistence.
public protocol PortfolioRepository: Sendable {}

/// Brokerage file import port. Concrete CSV adapters live in Importing.
public protocol BrokerageImporting: Sendable {}

/// Latest quote port. Concrete Yahoo-style adapter lives in MarketData.
public protocol QuoteProviding: Sendable {}

/// Five-minute intraday history port.
public protocol IntradayPriceProviding: Sendable {}

/// Daily historical close port.
public protocol HistoricalPriceProviding: Sendable {}
