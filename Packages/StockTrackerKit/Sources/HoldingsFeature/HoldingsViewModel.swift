import Application
import Foundation
import Observation

@MainActor
@Observable
public final class HoldingsViewModel {
    public enum Sort: String, CaseIterable, Identifiable {
        case marketValue
        case symbol
        case dayChange

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .marketValue: "Value"
            case .symbol: "Symbol"
            case .dayChange: "Today"
            }
        }
    }

    public private(set) var readModel: PortfolioHoldingsReadModel?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    public var sort: Sort = .marketValue

    private let getHoldings: GetPortfolioHoldings

    public init(getHoldings: GetPortfolioHoldings) {
        self.getHoldings = getHoldings
    }

    public var sortedHoldings: [HoldingRowReadModel] {
        guard let holdings = readModel?.holdings else { return [] }
        switch sort {
        case .marketValue:
            return holdings.sorted { ($0.marketValue?.amount ?? 0) > ($1.marketValue?.amount ?? 0) }
        case .symbol:
            return holdings.sorted { $0.displaySymbol.rawValue < $1.displaySymbol.rawValue }
        case .dayChange:
            return holdings.sorted { ($0.dayChange?.amount ?? 0) > ($1.dayChange?.amount ?? 0) }
        }
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            readModel = try await getHoldings()
        } catch {
            errorMessage = "Couldn't load holdings."
        }
    }
}
