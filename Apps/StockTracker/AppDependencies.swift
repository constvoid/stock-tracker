import Application
import Foundation

/// Composition root. Constructed once and passed explicitly — no service locator.
struct AppDependencies: Sendable {
    let portfolioRepository: any PortfolioRepository
    let brokerageImporting: any BrokerageImporting
    let quoteProviding: any QuoteProviding
    let intradayPriceProviding: any IntradayPriceProviding
    let historicalPriceProviding: any HistoricalPriceProviding

    static func makeDeterministicFakes() -> AppDependencies {
        AppDependencies(
            portfolioRepository: FakePortfolioRepository(),
            brokerageImporting: FakeBrokerageImporting(),
            quoteProviding: FakeQuoteProviding(),
            intradayPriceProviding: FakeIntradayPriceProviding(),
            historicalPriceProviding: FakeHistoricalPriceProviding()
        )
    }
}

private struct FakePortfolioRepository: PortfolioRepository {}
private struct FakeBrokerageImporting: BrokerageImporting {}
private struct FakeQuoteProviding: QuoteProviding {}
private struct FakeIntradayPriceProviding: IntradayPriceProviding {}
private struct FakeHistoricalPriceProviding: HistoricalPriceProviding {}
