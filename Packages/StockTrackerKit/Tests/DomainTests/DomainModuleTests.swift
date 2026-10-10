import Domain
import Foundation
import Testing

@Test("ACCT-003 cash-only account is valid")
func cashOnlyAccountIsValid() throws {
    let brokerageID = BrokerageID("fixture-broker")
    let account = BrokerageAccount(
        brokerageID: brokerageID,
        sourceKey: SourceAccountKey(brokerageID: brokerageID, externalReference: "222"),
        sourceDisplayName: "Cash_Only ...222",
        cash: try Money.usd(500),
        lastImportedAt: Date(timeIntervalSince1970: 1_700_000_000),
        slices: []
    )
    #expect(account.isCashOnly)
    #expect(account.isEnabled)
}
