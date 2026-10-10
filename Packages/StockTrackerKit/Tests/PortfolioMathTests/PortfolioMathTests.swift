import Domain
import Foundation
import PortfolioMath
import Testing

private let importedAt = Date(timeIntervalSince1970: 1_700_000_000)
private let acquired = Date(timeIntervalSince1970: 1_600_000_000)

private func provenance() -> ImportProvenance {
    ImportProvenance(parserIdentifier: "fixture", parserVersion: 1, importedAt: importedAt)
}

private func exactSlice(
    accountID: AccountID,
    symbol: String,
    quantity: Decimal,
    unitCost: Decimal,
    acquiredAt: Date = acquired
) throws -> PositionSlice {
    try PositionSlice(
        accountID: accountID,
        nativeSymbol: NativeSymbol(symbol),
        canonicalSymbol: CanonicalSymbol(symbol.replacingOccurrences(of: "/", with: ".")),
        securityKind: .equity,
        quantity: Quantity(shares: quantity),
        unitCost: UnitCost.usd(unitCost),
        acquiredAt: acquiredAt,
        basisKind: .exactAcquisition,
        provenance: provenance()
    )
}

private func aggregateSlice(
    accountID: AccountID,
    symbol: String,
    quantity: Decimal,
    unitCost: Decimal,
    kind: SecurityKind = .equity
) throws -> PositionSlice {
    try PositionSlice(
        accountID: accountID,
        nativeSymbol: NativeSymbol(symbol),
        canonicalSymbol: CanonicalSymbol(symbol.replacingOccurrences(of: "/", with: ".")),
        securityKind: kind,
        quantity: Quantity(shares: quantity),
        unitCost: UnitCost.usd(unitCost),
        acquiredAt: nil,
        basisKind: .aggregatePosition,
        provenance: provenance()
    )
}

private func quote(_ symbol: String, price: Decimal, previous: Decimal? = nil) throws -> Quote {
    Quote(
        canonicalSymbol: CanonicalSymbol(symbol),
        price: try Money.usd(price),
        previousClose: try previous.map { try Money.usd($0) },
        asOf: importedAt,
        source: .brokerImport,
        freshness: .fresh
    )
}

@Test("CALC-001 weighted average cost with fractional quantities and multiple slices")
func weightedAverageCostFractionalAndMultipleSlices() throws {
    let accountID = AccountID()
    let slices = try [
        exactSlice(accountID: accountID, symbol: "AAAX", quantity: 2.5, unitCost: 40),
        exactSlice(accountID: accountID, symbol: "AAAX", quantity: 7.5, unitCost: 60),
    ]
    // (2.5*40 + 7.5*60) / 10 = (100 + 450) / 10 = 55
    let average = try #require(try CostBasisMath.weightedAverageCost(slices: slices))
    #expect(average.amount == Decimal(55))
    #expect(try CostBasisMath.totalCostBasis(slices: slices).amount == Decimal(550))
    #expect(try CostBasisMath.totalQuantity(slices: slices).shares == Decimal(10))
}

@Test("CALC-002 cash-only and mixed accounts roll up independently")
func cashOnlyAndMixedAccountRollups() throws {
    let brokerage = BrokerageID("fixture-broker")
    let cashAccountID = AccountID()
    let mixedAccountID = AccountID()

    let cashOnly = BrokerageAccount(
        id: cashAccountID,
        brokerageID: brokerage,
        sourceKey: SourceAccountKey(brokerageID: brokerage, externalReference: "222"),
        sourceDisplayName: "Cash_Only ...222",
        cash: try Money.usd(500),
        lastImportedAt: importedAt,
        slices: []
    )

    let mixed = BrokerageAccount(
        id: mixedAccountID,
        brokerageID: brokerage,
        sourceKey: SourceAccountKey(brokerageID: brokerage, externalReference: "111"),
        sourceDisplayName: "Joint ...111",
        cash: try Money.usd(150),
        lastImportedAt: importedAt,
        slices: [
            try aggregateSlice(accountID: mixedAccountID, symbol: "AAAX", quantity: 10, unitCost: 80),
            try aggregateSlice(accountID: mixedAccountID, symbol: "ETFX", quantity: 5, unitCost: 40, kind: .etf),
        ]
    )

    let quotes = try [
        CanonicalSymbol("AAAX"): quote("AAAX", price: 100),
        CanonicalSymbol("ETFX"): quote("ETFX", price: 50),
    ]

    let cashRollup = try RollupMath.accountRollup(account: cashOnly, quotes: quotes)
    #expect(cashRollup.equityValue.amount == 0)
    #expect(cashRollup.totalValue.amount == 500)

    let mixedRollup = try RollupMath.accountRollup(account: mixed, quotes: quotes)
    // equity = 10*100 + 5*50 = 1250; total = 1250 + 150 = 1400
    #expect(mixedRollup.equityValue.amount == 1250)
    #expect(mixedRollup.totalValue.amount == 1400)

    let portfolio = try RollupMath.portfolioRollup(accounts: [cashOnly, mixed], quotes: quotes)
    #expect(portfolio.cashValue.amount == 650)
    #expect(portfolio.equityValue.amount == 1250)
    #expect(portfolio.totalValue.amount == 1900)
}

@Test("CALC-002 / ACCT-002 hidden accounts excluded from portfolio rollup")
func hiddenAccountsExcludedFromPortfolio() throws {
    let brokerage = BrokerageID("fixture-broker")
    let visibleID = AccountID()
    let hiddenID = AccountID()

    let visible = BrokerageAccount(
        id: visibleID,
        brokerageID: brokerage,
        sourceKey: SourceAccountKey(brokerageID: brokerage, externalReference: "111"),
        sourceDisplayName: "Visible",
        cash: try Money.usd(100),
        isEnabled: true,
        lastImportedAt: importedAt,
        slices: [try aggregateSlice(accountID: visibleID, symbol: "AAAX", quantity: 1, unitCost: 50)]
    )
    let hidden = BrokerageAccount(
        id: hiddenID,
        brokerageID: brokerage,
        sourceKey: SourceAccountKey(brokerageID: brokerage, externalReference: "999"),
        sourceDisplayName: "Hidden",
        cash: try Money.usd(9_999),
        isEnabled: false,
        lastImportedAt: importedAt,
        slices: [try aggregateSlice(accountID: hiddenID, symbol: "BBBX", quantity: 100, unitCost: 10)]
    )

    let quotes = try [
        CanonicalSymbol("AAAX"): quote("AAAX", price: 80),
        CanonicalSymbol("BBBX"): quote("BBBX", price: 20),
    ]

    let portfolio = try RollupMath.portfolioRollup(accounts: [visible, hidden], quotes: quotes)
    #expect(portfolio.totalValue.amount == 180) // 80 + 100
    #expect(portfolio.holdings.map(\.canonicalSymbol.rawValue) == ["AAAX"])
    #expect(portfolio.accountRollups.map(\.accountID) == [visibleID])
}

@Test("CALC-003 duplicate symbols aggregate across enabled accounts")
func duplicateSymbolsAggregateAcrossAccounts() throws {
    let brokerage = BrokerageID("fixture-broker")
    let a = AccountID()
    let b = AccountID()

    let accountA = BrokerageAccount(
        id: a,
        brokerageID: brokerage,
        sourceKey: SourceAccountKey(brokerageID: brokerage, externalReference: "111"),
        sourceDisplayName: "A",
        cash: try Money.usd(0),
        lastImportedAt: importedAt,
        slices: [try exactSlice(accountID: a, symbol: "BRK/B", quantity: 2, unitCost: 150)]
    )
    let accountB = BrokerageAccount(
        id: b,
        brokerageID: brokerage,
        sourceKey: SourceAccountKey(brokerageID: brokerage, externalReference: "333"),
        sourceDisplayName: "B",
        cash: try Money.usd(0),
        lastImportedAt: importedAt,
        slices: [try aggregateSlice(accountID: b, symbol: "BRK/B", quantity: 3, unitCost: 180)]
    )

    let quotes = try [CanonicalSymbol("BRK.B"): quote("BRK.B", price: 200, previous: 190)]
    let portfolio = try RollupMath.portfolioRollup(accounts: [accountA, accountB], quotes: quotes)

    #expect(portfolio.holdings.count == 1)
    let holding = try #require(portfolio.holdings.first)
    #expect(holding.canonicalSymbol.rawValue == "BRK.B")
    #expect(holding.quantity.shares == 5)
    // avg = (2*150 + 3*180) / 5 = (300 + 540) / 5 = 168
    #expect(holding.averageCost.amount == 168)
    #expect(holding.marketValue?.amount == 1000)
    #expect(holding.accountAllocations[a]?.shares == 2)
    #expect(holding.accountAllocations[b]?.shares == 3)

    let detailA = try RollupMath.accountRollup(account: accountA, quotes: quotes)
    #expect(detailA.positions.count == 1)
    #expect(detailA.positions[0].quantity.shares == 2)
}

@Test("CALC-004 one unknown acquisition date disables account tax-term")
func unknownDateDisablesTaxTerm() throws {
    let accountID = AccountID()
    let dated = try exactSlice(accountID: accountID, symbol: "AAAX", quantity: 1, unitCost: 10)
    let undated = try aggregateSlice(accountID: accountID, symbol: "BBBX", quantity: 1, unitCost: 10)

    let allDated = CapabilityDerivation.accountCapabilities(slices: [dated])
    #expect(allDated.taxTerm == .available)
    #expect(allDated.history == .reconstructed)

    let mixed = CapabilityDerivation.accountCapabilities(slices: [dated, undated])
    #expect(mixed.taxTerm == .unavailableMissingAcquisitionDates)
    #expect(mixed.history == .estimatedUnknownAcquisitionDates)

    let brokerage = BrokerageID("fixture-broker")
    let estimatedAccount = BrokerageAccount(
        id: accountID,
        brokerageID: brokerage,
        sourceKey: SourceAccountKey(brokerageID: brokerage, externalReference: "1"),
        sourceDisplayName: "Mixed",
        cash: try Money.usd(0),
        lastImportedAt: importedAt,
        slices: [dated, undated]
    )
    let datedAccount = BrokerageAccount(
        id: AccountID(),
        brokerageID: brokerage,
        sourceKey: SourceAccountKey(brokerageID: brokerage, externalReference: "2"),
        sourceDisplayName: "Dated",
        cash: try Money.usd(0),
        lastImportedAt: importedAt,
        slices: [dated]
    )
    #expect(
        CapabilityDerivation.portfolioHistoryQuality(accounts: [estimatedAccount, datedAccount])
            == .estimatedUnknownAcquisitionDates
    )
}
