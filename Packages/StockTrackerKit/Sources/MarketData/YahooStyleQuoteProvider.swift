import Application
import Domain
import Foundation

/// Yahoo Finance chart-meta quote adapter. Prefer extended-hours last price when present.
public struct YahooStyleQuoteProvider: QuoteProviding {
    private let client: any HTTPClient
    private let includeExtendedHours: Bool

    public init(client: any HTTPClient = URLSessionHTTPClient(), includeExtendedHours: Bool = true) {
        self.client = client
        self.includeExtendedHours = includeExtendedHours
    }

    public func quotes(for symbols: [CanonicalSymbol]) async throws -> [CanonicalSymbol: Quote] {
        try await withThrowingTaskGroup(of: (CanonicalSymbol, Quote)?.self) { group in
            for symbol in symbols {
                group.addTask {
                    try await self.fetchQuote(for: symbol)
                }
            }
            var result: [CanonicalSymbol: Quote] = [:]
            for try await item in group {
                if let item {
                    result[item.0] = item.1
                }
            }
            if result.isEmpty, !symbols.isEmpty {
                throw MarketDataError.emptyResponse
            }
            return result
        }
    }

    private func fetchQuote(for symbol: CanonicalSymbol) async throws -> (CanonicalSymbol, Quote)? {
        let yahoo = ProviderSymbolMapping.yahooSymbol(from: symbol)
        guard var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(yahoo)") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "range", value: "5d"),
            URLQueryItem(name: "includePrePost", value: includeExtendedHours ? "true" : "false"),
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await client.data(for: request)
        } catch {
            throw MarketDataError.networkFailure
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MarketDataError.networkFailure
        }

        do {
            guard let quote = try YahooChartQuoteParser.parse(
                data: data,
                canonicalSymbol: symbol,
                includeExtendedHours: includeExtendedHours
            ) else {
                return nil
            }
            return (symbol, quote)
        } catch {
            throw MarketDataError.decodingFailure
        }
    }
}

public enum YahooChartQuoteParser {
    public static func parse(
        data: Data,
        canonicalSymbol: CanonicalSymbol,
        includeExtendedHours: Bool
    ) throws -> Quote? {
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let chart = root?["chart"] as? [String: Any]
        let results = chart?["result"] as? [[String: Any]]
        guard let meta = results?.first?["meta"] as? [String: Any] else {
            return nil
        }

        let previous = decimal(meta["chartPreviousClose"]) ?? decimal(meta["previousClose"])
        let regularPrice = decimal(meta["regularMarketPrice"])
        let regularTime = date(meta["regularMarketTime"]) ?? Date()

        var candidates: [(Decimal, Date, MarketSession)] = []
        if let regularPrice {
            candidates.append((regularPrice, regularTime, .regular))
        }
        if includeExtendedHours {
            if let pre = decimal(meta["preMarketPrice"]), let t = date(meta["preMarketTime"]) {
                candidates.append((pre, t, .pre))
            }
            if let post = decimal(meta["postMarketPrice"]), let t = date(meta["postMarketTime"]) {
                candidates.append((post, t, .post))
            }
        }

        guard let best = candidates.max(by: { $0.1 < $1.1 }) else { return nil }
        let previousMoney = try previous.map { try Money.usd($0) }
        return Quote(
            canonicalSymbol: canonicalSymbol,
            price: try Money.usd(best.0),
            previousClose: previousMoney,
            asOf: best.1,
            source: .marketProvider,
            freshness: .fresh,
            session: best.2
        )
    }

    private static func decimal(_ any: Any?) -> Decimal? {
        if let number = any as? NSNumber {
            return number.decimalValue
        }
        if let double = any as? Double {
            return Decimal(double)
        }
        if let string = any as? String {
            return Decimal(string: string)
        }
        return nil
    }

    private static func date(_ any: Any?) -> Date? {
        if let number = any as? NSNumber {
            return Date(timeIntervalSince1970: number.doubleValue)
        }
        if let double = any as? Double {
            return Date(timeIntervalSince1970: double)
        }
        return nil
    }
}
