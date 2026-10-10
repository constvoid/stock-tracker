import Application
import Foundation

public struct FileBrokerageImporting: BrokerageImporting {
    private let registry: BrokerageFileParserRegistry
    private let clock: @Sendable () -> Date

    public init(
        registry: BrokerageFileParserRegistry = BrokerageFileParserRegistry(),
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.registry = registry
        self.clock = clock
    }

    public func inspect(files: [URL]) async throws -> [BrokerageImportBatch] {
        let importedAt = clock()
        var batches: [BrokerageImportBatch] = []
        var seenBrokerages = Set<String>()

        for fileURL in files {
            let batch = try registry.parse(fileURL: fileURL, importedAt: importedAt)
            let brokerageKey = batch.brokerage.id.rawValue
            if seenBrokerages.contains(brokerageKey), !batch.hasFileLevelBlockingIssues {
                // At most one current file per brokerage in an operation.
                var issues = batch.issues
                issues.append(
                    ImportIssueFactory.fileError(
                        code: "duplicate_brokerage_file",
                        message: "Only one complete file per brokerage is accepted in an import operation."
                    )
                )
                batches.append(
                    BrokerageImportBatch(
                        brokerage: batch.brokerage,
                        coverage: batch.coverage,
                        source: batch.source,
                        accounts: [],
                        issues: issues
                    )
                )
                continue
            }
            if !batch.hasFileLevelBlockingIssues {
                seenBrokerages.insert(brokerageKey)
            }
            batches.append(batch)
        }
        return batches
    }
}
