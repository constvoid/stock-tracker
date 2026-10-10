import Domain
import Foundation
import MarketData
import Testing

@Test("MKT-001 provider symbol aliases map share classes")
func providerSymbolAliases() {
    #expect(ProviderSymbolMapping.yahooSymbol(from: CanonicalSymbol("BRK.B")) == "BRK-B")
    #expect(ProviderSymbolMapping.canonical(fromYahoo: "BRK-B").rawValue == "BRK.B")
}

@Test("MKT-001 extended-hours price preferred over older regular print")
func extendedHoursPreferred() throws {
    let json = """
    {
      "chart": {
        "result": [{
          "meta": {
            "regularMarketPrice": 100,
            "regularMarketTime": 1700000000,
            "chartPreviousClose": 95,
            "postMarketPrice": 102.5,
            "postMarketTime": 1700003600
          }
        }]
      }
    }
    """.data(using: .utf8)!

    let quote = try #require(
        try YahooChartQuoteParser.parse(
            data: json,
            canonicalSymbol: CanonicalSymbol("AAAX"),
            includeExtendedHours: true
        )
    )
    #expect(quote.price.amount == Decimal(string: "102.5"))
    #expect(quote.session == .post)
    #expect(quote.previousClose?.amount == 95)
}

@Test("MKT-001 extended hours ignored when disabled")
func extendedHoursIgnoredWhenDisabled() throws {
    let json = """
    {
      "chart": {
        "result": [{
          "meta": {
            "regularMarketPrice": 100,
            "regularMarketTime": 1700000000,
            "previousClose": 95,
            "postMarketPrice": 102.5,
            "postMarketTime": 1700003600
          }
        }]
      }
    }
    """.data(using: .utf8)!

    let quote = try #require(
        try YahooChartQuoteParser.parse(
            data: json,
            canonicalSymbol: CanonicalSymbol("AAAX"),
            includeExtendedHours: false
        )
    )
    #expect(quote.price.amount == 100)
    #expect(quote.session == .regular)
}
