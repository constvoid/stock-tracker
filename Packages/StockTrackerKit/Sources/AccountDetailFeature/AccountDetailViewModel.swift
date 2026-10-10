import Application
import DesignSystem
import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class AccountDetailViewModel {
    public private(set) var readModel: AccountDetailReadModel?
    public private(set) var series: HistoricalSeries?
    public private(set) var selectedRange: TimeRange = .month
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private let accountID: AccountID
    private let getAccountDetail: GetAccountDetail
    private let getHistoricalValue: GetHistoricalValue?

    public init(
        accountID: AccountID,
        getAccountDetail: GetAccountDetail,
        getHistoricalValue: GetHistoricalValue? = nil
    ) {
        self.accountID = accountID
        self.getAccountDetail = getAccountDetail
        self.getHistoricalValue = getHistoricalValue
    }

    public var chartPoints: [ChartValuePoint] {
        (series?.points ?? []).map {
            ChartValuePoint(
                date: $0.timestamp,
                value: NSDecimalNumber(decimal: $0.value.amount).doubleValue
            )
        }
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            readModel = try await getAccountDetail(accountID: accountID)
            if readModel == nil {
                errorMessage = "Account not found."
            } else {
                await loadHistory()
            }
        } catch {
            errorMessage = "Couldn't load account."
        }
    }

    public func selectRangeID(_ id: String) async {
        guard let range = TimeRange(rawValue: id) else { return }
        selectedRange = range
        await loadHistory()
    }

    private func loadHistory() async {
        guard let getHistoricalValue else { return }
        do {
            series = try await getHistoricalValue(scope: .account(accountID), range: selectedRange)
        } catch {
            series = HistoricalSeries(
                range: selectedRange,
                points: [],
                quality: .reconstructed,
                disclosure: "Historical market data unavailable.",
                asOf: nil
            )
        }
    }
}
