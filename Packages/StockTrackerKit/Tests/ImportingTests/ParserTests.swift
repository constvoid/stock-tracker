import Application
import Domain
import Foundation
import Importing
import Testing

@Test("IMP-001 / IMP-002 registry detects Schwab and E*TRADE fixtures")
func registryDetectsBrokerageFixtures() throws {
    let registry = BrokerageFileParserRegistry()
    let importedAt = Date(timeIntervalSince1970: 1_700_000_000)

    let schwab = try registry.parse(
        fileURL: FixtureLoader.url("schwab-positions-multi-account"),
        importedAt: importedAt
    )
    #expect(schwab.brokerage.id.rawValue == "schwab")
    #expect(schwab.accounts.count == 3)
    #expect(!schwab.hasFileLevelBlockingIssues)

    let etrade = try registry.parse(
        fileURL: FixtureLoader.url("etrade-portfolio-single-account"),
        importedAt: importedAt
    )
    #expect(etrade.brokerage.id.rawValue == "etrade")
    #expect(etrade.accounts.count == 1)
    #expect(!etrade.hasFileLevelBlockingIssues)
}

@Test("IMP-002 Schwab yields cash-only, fractional, ETF, and slash-symbol accounts")
func schwabParsesEdgeCases() throws {
    let batch = try BrokerageFileParserRegistry().parse(
        fileURL: FixtureLoader.url("schwab-positions-multi-account"),
        importedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    let cashOnly = try #require(batch.accounts.first { $0.sourceAccountKey.externalReference == "222" })
    #expect(cashOnly.slices.isEmpty)
    #expect(cashOnly.cash.amount == Decimal(500))

    let joint = try #require(batch.accounts.first { $0.sourceAccountKey.externalReference == "111" })
    #expect(joint.slices.contains { $0.quantity == Decimal(string: "2.5") })
    #expect(joint.slices.contains { $0.securityKind == .etf })

    let individual = try #require(batch.accounts.first { $0.sourceAccountKey.externalReference == "333" })
    let slash = try #require(individual.slices.first { $0.nativeSymbol == "BRK/B" })
    #expect(slash.canonicalSymbolCandidate == "BRK.B")
    #expect(SymbolMapping.providerAlias(fromNative: "BRK/B") == "BRK-B")
    #expect(slash.basisKind == .aggregatePosition)
    #expect(individual.issues.contains { $0.code == "unknown_acquisition_date" })
}

@Test("IMP-003 E*TRADE yields exact acquisition slices")
func etradeParsesExactLots() throws {
    let batch = try BrokerageFileParserRegistry().parse(
        fileURL: FixtureLoader.url("etrade-portfolio-single-account"),
        importedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let account = try #require(batch.accounts.first)
    #expect(account.sourceAccountKey.externalReference == "9999")
    #expect(account.slices.allSatisfy { $0.basisKind == .exactAcquisition && $0.acquiredAt != nil })
    #expect(account.cash.amount == Decimal(200))
    #expect(account.issues.contains { $0.code == "rounding_mismatch" && $0.severity == .warning })
}

@Test("IMP-005 malformed Schwab row blocks only that account")
func malformedRowBlocksAccount() throws {
    let batch = try BrokerageFileParserRegistry().parse(
        fileURL: FixtureLoader.url("schwab-malformed-row"),
        importedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let joint = try #require(batch.accounts.first { $0.sourceAccountKey.externalReference == "111" })
    #expect(joint.hasBlockingIssues)
    #expect(joint.issues.contains { $0.code == "malformed_quantity" })

    let cashOnly = try #require(batch.accounts.first { $0.sourceAccountKey.externalReference == "222" })
    #expect(!cashOnly.hasBlockingIssues)
}

@Test("IMP-001 unknown file produces file-level error")
func unknownFileBlocked() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("unknown-\(UUID().uuidString).csv")
    try "hello,world\n1,2\n".write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }

    let batch = try BrokerageFileParserRegistry().parse(fileURL: url, importedAt: Date())
    #expect(batch.hasFileLevelBlockingIssues)
    #expect(batch.issues.contains { $0.code == "unknown_format" })
    #expect(!batch.issues.contains { $0.redactedMessage.contains("hello,world") })
}

@Test("IMP-007 slash symbol mapping")
func slashSymbolMapping() {
    #expect(SymbolMapping.canonical(fromNative: "BRK/B") == "BRK.B")
    #expect(SymbolMapping.providerAlias(fromCanonical: "BRK.B") == "BRK-B")
}
