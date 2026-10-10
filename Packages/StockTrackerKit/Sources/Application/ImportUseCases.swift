import Domain
import Foundation

public struct PreviewBrokerageImports: Sendable {
    private let repository: any PortfolioRepository

    public init(repository: any PortfolioRepository) {
        self.repository = repository
    }

    public func callAsFunction(_ batches: [BrokerageImportBatch]) async throws -> [BrokerageImportPreview] {
        var previews: [BrokerageImportPreview] = []
        for batch in batches {
            previews.append(try await preview(batch: batch))
        }
        return previews
    }

    private func preview(batch: BrokerageImportBatch) async throws -> BrokerageImportPreview {
        if batch.hasFileLevelBlockingIssues {
            let blocked = batch.accounts.map { account in
                AccountImportPreview(
                    sourceAccountKey: account.sourceAccountKey,
                    displayName: account.displayName,
                    disposition: .blocked,
                    willCommit: false,
                    cash: account.cash,
                    positionCount: account.slices.count,
                    issues: batch.issues + account.issues,
                    existingAccountID: nil
                )
            }
            return BrokerageImportPreview(batch: batch, accounts: blocked, staleAccounts: [])
        }

        let snapshot = try await repository.portfolioSnapshot()
        let existingForBrokerage = snapshot.accounts.filter { $0.brokerageID == batch.brokerage.id }
        let presentKeys = Set(batch.accounts.map(\.sourceAccountKey))

        var accountPreviews: [AccountImportPreview] = []
        for account in batch.accounts {
            let existing = existingForBrokerage.first { $0.sourceKey == account.sourceAccountKey }
            let blocked = account.hasBlockingIssues
            let disposition: AccountImportDisposition
            if blocked {
                disposition = .blocked
            } else if existing == nil {
                disposition = .new
            } else {
                disposition = .updated
            }
            accountPreviews.append(
                AccountImportPreview(
                    sourceAccountKey: account.sourceAccountKey,
                    displayName: account.displayName,
                    disposition: disposition,
                    willCommit: !blocked,
                    cash: account.cash,
                    positionCount: account.slices.count,
                    issues: account.issues,
                    existingAccountID: existing?.id
                )
            )
        }

        let stale = existingForBrokerage
            .filter { !presentKeys.contains($0.sourceKey) }
            .map { account in
                AccountImportPreview(
                    sourceAccountKey: account.sourceKey,
                    displayName: account.displayName,
                    disposition: .stale,
                    willCommit: false,
                    cash: account.cash,
                    positionCount: account.slices.count,
                    issues: [],
                    existingAccountID: account.id
                )
            }

        return BrokerageImportPreview(batch: batch, accounts: accountPreviews, staleAccounts: stale)
    }
}

public struct CommitAccountImports: Sendable {
    private let repository: any PortfolioRepository

    public init(repository: any PortfolioRepository) {
        self.repository = repository
    }

    public func callAsFunction(_ batches: [BrokerageImportBatch]) async throws -> ImportCommitResult {
        var accountResults: [AccountCommitResult] = []
        var staleIDs: [AccountID] = []

        for batch in batches {
            if batch.hasFileLevelBlockingIssues {
                for account in batch.accounts {
                    accountResults.append(
                        AccountCommitResult(
                            sourceAccountKey: account.sourceAccountKey,
                            accountID: nil,
                            committed: false,
                            issues: batch.issues + account.issues
                        )
                    )
                }
                continue
            }

            var committedKeys: [SourceAccountKey] = []
            for account in batch.accounts {
                if account.hasBlockingIssues {
                    let existing = try await repository.account(sourceKey: account.sourceAccountKey)
                    accountResults.append(
                        AccountCommitResult(
                            sourceAccountKey: account.sourceAccountKey,
                            accountID: existing?.id,
                            committed: false,
                            issues: account.issues
                        )
                    )
                    continue
                }

                let existing = try await repository.account(sourceKey: account.sourceAccountKey)
                let replacement = try ImportMapping.replacementSnapshot(
                    from: account,
                    brokerage: batch.brokerage,
                    source: batch.source,
                    existingAccountID: existing?.id
                )
                let audit = makeAudit(batch: batch, accounts: [account])
                let accountID = try await repository.replaceAccount(replacement, audit: audit)
                committedKeys.append(account.sourceAccountKey)
                accountResults.append(
                    AccountCommitResult(
                        sourceAccountKey: account.sourceAccountKey,
                        accountID: accountID,
                        committed: true,
                        issues: account.issues
                    )
                )
            }

            if !committedKeys.isEmpty {
                let marked = try await repository.markMissingAccountsStale(
                    brokerageID: batch.brokerage.id,
                    presentKeys: batch.accounts.map(\.sourceAccountKey),
                    asOf: batch.source.importedAt
                )
                staleIDs.append(contentsOf: marked)
            }
        }

        return ImportCommitResult(accountResults: accountResults, staleAccountIDs: staleIDs)
    }

    private func makeAudit(batch: BrokerageImportBatch, accounts: [ImportedAccountSnapshot]) -> ImportAuditMetadata {
        let issues = batch.issues + accounts.flatMap(\.issues)
        return ImportAuditMetadata(
            brokerageID: batch.brokerage.id,
            originalFilename: batch.source.originalFilename,
            providerTimestamp: batch.source.providerTimestamp,
            importedAt: batch.source.importedAt,
            contentFingerprint: batch.source.contentFingerprint,
            parserIdentifier: batch.source.parserIdentifier,
            parserVersion: batch.source.parserVersion,
            accountCount: accounts.count,
            positionCount: accounts.reduce(0) { $0 + $1.slices.count },
            warningCount: issues.filter { $0.severity == .warning }.count,
            errorCount: issues.filter { $0.severity == .error }.count,
            issueCodes: Array(Set(issues.map(\.code))).sorted()
        )
    }
}
