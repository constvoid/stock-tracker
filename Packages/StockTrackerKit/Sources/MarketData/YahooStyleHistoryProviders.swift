import Application
import Domain
import Foundation

public struct YahooStyleIntradayProvider: IntradayPriceProviding {
    private let client: any HTTPClient
    private let includeExtendedHours: Bool

    public init(client: any HTTPClient = URLSessionHTTPClient(), includeExtendedHours: Bool = true) {
        self.client = client
        self.includeExtendedHours = includeExtendedHours
    }

    public func bars(for symbols: [CanonicalSymbol], day: Date) async throws -> [CanonicalSymbol: [PriceBar]] {
        try await fetch(symbols: symbols, interval: "5m", range: "1d", barInterval: .fiveMinute)
    }

    private func fetch(
        symbols: [CanonicalSymbol],
        interval: String,
        range: String,
        barInterval: PriceBarInterval
    ) async throws -> [CanonicalSymbol: [PriceBar]] {
        try await withThrowingTaskGroup(of: (CanonicalSymbol, [PriceBar]).self) { group in
            for symbol in symbols {
                group.addTask {
                    let bars = try await YahooChartBarsParser.fetchBars(
                        symbol: symbol,
                        interval: interval,
                        range: range,
                        barInterval: barInterval,
                        includePrePost: includeExtendedHours,
                        client: client
                    )
                    return (symbol, bars)
                }
            }
            var result: [CanonicalSymbol: [PriceBar]] = [:]
            for try await item in group {
                result[item.0] = item.1
            }
            return result
        }
    }
}

public struct YahooStyleHistoricalProvider: HistoricalPriceProviding {
    private let client: any HTTPClient

    public init(client: any HTTPClient = URLSessionHTTPClient()) {
        self.client = client
    }

    public func dailyBars(
        for symbols: [CanonicalSymbol],
        range: TimeRange
    ) async throws -> [CanonicalSymbol: [PriceBar]] {
        let yahooRange = Self.yahooRange(for: range)
        return try await withThrowingTaskGroup(of: (CanonicalSymbol, [PriceBar]).self) { group in
            for symbol in symbols {
                group.addTask {
                    let bars = try await YahooChartBarsParser.fetchBars(
                        symbol: symbol,
                        interval: "1d",
                        range: yahooRange,
                        barInterval: .daily,
                        includePrePost: false,
                        client: client
                    )
                    return (symbol, bars)
                }
            }
            var result: [CanonicalSymbol: [PriceBar]] = [:]
            for try await item in group {
                result[item.0] = item.1
            }
            return result
        }
    }

    public static func yahooRange(for range: TimeRange) -> String {
        switch range {
        case .day: "1d"
        case .week: "5d"
        case .month: "1mo"
        case .ytd: "ytd"
        case .oneYear: "1y"
        case .threeYears: "3y"
        case .fiveYears: "5y"
        }
    }
}

public struct FakeIntradayProvider: IntradayPriceProviding {
    public var barsBySymbol: [CanonicalSymbol: [PriceBar]]
    public var shouldFail: Bool

    public init(barsBySymbol: [CanonicalSymbol: [PriceBar]] = [:], shouldFail: Bool = false) {
        self.barsBySymbol = barsBySymbol
        self.shouldFail = shouldFail
    }

    public func bars(for symbols: [CanonicalSymbol], day: Date) async throws -> [CanonicalSymbol: [PriceBar]] {
        if shouldFail { throw MarketDataError.networkFailure }
        var result: [CanonicalSymbol: [PriceBar]] = [:]
        for symbol in symbols {
            result[symbol] = barsBySymbol[symbol] ?? []
        }
        return result
    }
}

public struct FakeHistoricalProvider: HistoricalPriceProviding {
    public var barsBySymbol: [CanonicalSymbol: [PriceBar]]
    public var shouldFail: Bool

    public init(barsBySymbol: [CanonicalSymbol: [PriceBar]] = [:], shouldFail: Bool = false) {
        self.barsBySymbol = barsBySymbol
        self.shouldFail = shouldFail
    }

    public func dailyBars(
        for symbols: [CanonicalSymbol],
        range: TimeRange
    ) async throws -> [CanonicalSymbol: [PriceBar]] {
        if shouldFail { throw MarketDataError.networkFailure }
        var result: [CanonicalSymbol: [PriceBar]] = [:]
        for symbol in symbols {
            result[symbol] = barsBySymbol[symbol] ?? []
        }
        return result
    }
}

enum YahooChartBarsParser {
    static func fetchBars(
        symbol: CanonicalSymbol,
        interval: String,
        range: String,
        barInterval: PriceBarInterval,
        includePrePost: Bool,
        client: any HTTPClient
    ) async throws -> [PriceBar] {
        let yahoo = ProviderSymbolMapping.yahooSymbol(from: symbol)
        guard var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(yahoo)") else {
            return []
        }
        components.queryItems = [
            URLQueryItem(name: "interval", value: interval),
            URLQueryItem(name: "range", value: range),
            URLQueryItem(name: "includePrePost", value: includePrePost ? "true" : "false"),
        ]
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

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
        return try parse(data: data, symbol: symbol, interval: barInterval)
    }

    static func parse(data: Data, symbol: CanonicalSymbol, interval: PriceBarInterval) throws -> [PriceBar] {
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let result = (root?["chart"] as? [String: Any])?["result"] as? [[String: Any]]
        guard let first = result?.first,
              let timestamps = first["timestamp"] as? [Double],
              let indicators = first["indicators"] as? [String: Any],
              let quotes = (indicators["quote"] as? [[String: Any]])?.first,
              let closes = quotes["close"] as? [Any]
        else {
            return []
        }

        var bars: [PriceBar] = []
        for (index, ts) in timestamps.enumerated() {
            guard index < closes.count else { break }
            guard let closeNumber = decimal(closes[index]) else { continue }
            let close = try Money.usd(closeNumber)
            bars.append(
                PriceBar(
                    canonicalSymbol: symbol,
                    timestamp: Date(timeIntervalSince1970: ts),
                    close: close,
                    interval: interval,
                    source: .marketProvider
                )
            )
        }
        return bars
    }

    private static func decimal(_ any: Any) -> Decimal? {
        if any is NSNull { return nil }
        if let number = any as? NSNumber { return number.decimalValue }
        if let double = any as? Double { return Decimal(double) }
        return nil
    }
}
