import Application
import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class AccountDetailViewModel {
    public private(set) var readModel: AccountDetailReadModel?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private let accountID: AccountID
    private let getAccountDetail: GetAccountDetail

    public init(accountID: AccountID, getAccountDetail: GetAccountDetail) {
        self.accountID = accountID
        self.getAccountDetail = getAccountDetail
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            readModel = try await getAccountDetail(accountID: accountID)
            if readModel == nil {
                errorMessage = "Account not found."
            }
        } catch {
            errorMessage = "Couldn't load account."
        }
    }
}
