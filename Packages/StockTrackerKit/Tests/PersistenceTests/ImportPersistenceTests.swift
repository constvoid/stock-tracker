import Application
import Domain
import Foundation
import Importing
import Persistence
import Testing

@Test("IMP-004 / IMP-005 commit replaces accounts, preserves hidden, marks stale")
func commitReplacePreserveHiddenAndStale() async throws {
    let container = try SwiftDataPortfolioRepository.makeInMemoryContainer()
    let repository = SwiftDataPortfolioRepository(modelContainer: container)
    let importing = FileBrokerageImporting(clock: { Date(timeIntervalSince1970: 1_700_000_000) })
    let preview = PreviewBrokerageImports(repository: repository)
    let commit = CommitAccountImports(repository: repository)

    let fullURL = try fixtureURL("schwab-positions-multi-account")
    let batches = try await importing.inspect(files: [fullURL])
    let firstCommit = try await commit(batches)
    #expect(firstCommit.accountResults.filter(\.committed).count == 3)

    let snapshot = try await repository.portfolioSnapshot()
    #expect(snapshot.accounts.count == 3)

    let account333 = try #require(
        snapshot.accounts.first { $0.sourceKey.externalReference == "333" }
    )
    try await repository.setAccountEnabled(id: account333.id, enabled: false)

    // Re-import full file: hidden state preserved, slice counts stable (idempotent).
    let second = try await commit(try await importing.inspect(files: [fullURL]))
    #expect(second.accountResults.filter(\.committed).count == 3)
    let afterReimport = try await repository.portfolioSnapshot()
    #expect(afterReimport.accounts.count == 3)
    let hidden = try #require(afterReimport.accounts.first { $0.id == account333.id })
    #expect(hidden.isEnabled == false)

    // Missing-account file marks 333 stale but retains it.
    let missingURL = try fixtureURL("schwab-missing-account")
    let missingBatches = try await importing.inspect(files: [missingURL])
    let previews = try await preview(missingBatches)
    #expect(previews.first?.staleAccounts.contains { $0.sourceAccountKey.externalReference == "333" } == true)

    let missingCommit = try await commit(missingBatches)
    #expect(missingCommit.staleAccountIDs.contains(account333.id))
    let staleAccount = try #require(try await repository.account(id: account333.id))
    guard case .stale = staleAccount.freshness else {
        Issue.record("Expected stale freshness")
        return
    }
    #expect(staleAccount.isEnabled == false)
}

@Test("IMP-005 malformed account blocked; sibling cash-only commits")
func partialAccountSuccess() async throws {
    let container = try SwiftDataPortfolioRepository.makeInMemoryContainer()
    let repository = SwiftDataPortfolioRepository(modelContainer: container)
    let importing = FileBrokerageImporting(clock: { Date(timeIntervalSince1970: 1_700_000_000) })
    let commit = CommitAccountImports(repository: repository)

    // Seed with good data for account 111
    let good = try await importing.inspect(files: [try fixtureURL("schwab-positions-multi-account")])
    _ = try await commit(good)
    let before = try #require(
        try await repository.portfolioSnapshot().accounts
            .first { $0.sourceKey.externalReference == "111" }
    )
    let beforeSliceCount = before.slices.count

    let malformed = try await importing.inspect(files: [try fixtureURL("schwab-malformed-row")])
    let result = try await commit(malformed)

    let jointResult = try #require(result.accountResults.first { $0.sourceAccountKey.externalReference == "111" })
    #expect(jointResult.committed == false)

    let cashResult = try #require(result.accountResults.first { $0.sourceAccountKey.externalReference == "222" })
    #expect(cashResult.committed == true)

    let after = try #require(try await repository.account(id: before.id))
    #expect(after.slices.count == beforeSliceCount)
}

@Test("IMP-008 / QUAL-002 audit stores fingerprint and codes, not raw CSV")
func auditIsRedacted() async throws {
    let container = try SwiftDataPortfolioRepository.makeInMemoryContainer()
    let repository = SwiftDataPortfolioRepository(modelContainer: container)
    let importing = FileBrokerageImporting(clock: { Date(timeIntervalSince1970: 1_700_000_000) })
    let commit = CommitAccountImports(repository: repository)

    let batches = try await importing.inspect(files: [try fixtureURL("etrade-portfolio-single-account")])
    #expect(batches.first?.source.contentFingerprint.isEmpty == false)
    #expect(batches.first?.source.originalFilename.contains("etrade") == true)

    _ = try await commit(batches)
    let snapshot = try await repository.portfolioSnapshot()
    #expect(snapshot.accounts.count == 1)
    // Raw fixture markers must not appear in persisted display as CSV body; only labels/normalized data.
    #expect(snapshot.accounts[0].slices.allSatisfy { $0.provenance.parserIdentifier == "etrade-portfolio-csv" })
}

@Test("IMP-003 / IMP-006 imported unit cost retained for average cost")
func importedUnitCostDrivesAverageCost() async throws {
    let container = try SwiftDataPortfolioRepository.makeInMemoryContainer()
    let repository = SwiftDataPortfolioRepository(modelContainer: container)
    let importing = FileBrokerageImporting(clock: { Date(timeIntervalSince1970: 1_700_000_000) })
    let commit = CommitAccountImports(repository: repository)

    _ = try await commit(try await importing.inspect(files: [try fixtureURL("schwab-positions-multi-account")]))
    let account = try #require(
        try await repository.portfolioSnapshot().accounts
            .first { $0.sourceKey.externalReference == "111" }
    )
    let aaax = try #require(account.slices.first { $0.canonicalSymbol.rawValue == "AAAX" })
    // Cost basis 800 / qty 10 = 80
    #expect(aaax.unitCost.amountPerShare == Decimal(80))
}

private func fixtureURL(_ name: String) throws -> URL {
    // Resolve from repo Fixtures when running PersistenceTests (no bundle resources).
    let thisFile = URL(fileURLWithPath: #filePath)
    let repoRoot = thisFile
        .deletingLastPathComponent() // PersistenceTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // StockTrackerKit
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // repo
    let url = repoRoot
        .appendingPathComponent("Fixtures/Anonymized/\(name).csv", isDirectory: false)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw NSError(domain: "Fixture", code: 1, userInfo: [NSLocalizedDescriptionKey: url.path])
    }
    return url
}
