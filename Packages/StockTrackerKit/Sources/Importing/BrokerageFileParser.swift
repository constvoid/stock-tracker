import Application
import Domain
import Foundation

public struct ParserProbeResult: Sendable {
    public let confidence: Double
    public let brokerage: BrokerageIdentity

    public init(confidence: Double, brokerage: BrokerageIdentity) {
        self.confidence = confidence
        self.brokerage = brokerage
    }
}

public protocol BrokerageFileParser: Sendable {
    var identifier: String { get }
    var version: Int { get }
    func probe(filePrefix: String) -> ParserProbeResult?
    func parse(fileURL: URL, data: Data, importedAt: Date) throws -> BrokerageImportBatch
}

public enum BrokerageFileParserRegistryError: Error, Equatable, Sendable {
    case unknownFormat
    case ambiguousFormat
}

public struct BrokerageFileParserRegistry: Sendable {
    public static let confidenceThreshold = 0.6
    public static let probeByteLimit = 8_192

    private let parsers: [any BrokerageFileParser]

    public init(parsers: [any BrokerageFileParser] = [
        SchwabPositionsParser(),
        ETradePortfolioParser(),
    ]) {
        self.parsers = parsers
    }

    public func parse(fileURL: URL, importedAt: Date = Date()) throws -> BrokerageImportBatch {
        let data = try Data(contentsOf: fileURL)
        let prefixData = data.prefix(Self.probeByteLimit)
        let prefix = String(decoding: prefixData, as: UTF8.self)

        let matches = parsers.compactMap { parser -> (any BrokerageFileParser, ParserProbeResult)? in
            guard let probe = parser.probe(filePrefix: prefix),
                  probe.confidence >= Self.confidenceThreshold
            else { return nil }
            return (parser, probe)
        }

        if matches.isEmpty {
            return BrokerageImportBatch(
                brokerage: BrokerageIdentity(id: BrokerageID("unknown"), displayName: "Unknown"),
                source: ImportSourceMetadata(
                    originalFilename: fileURL.lastPathComponent,
                    providerTimestamp: nil,
                    importedAt: importedAt,
                    contentFingerprint: CSVSupport.fingerprint(of: data),
                    parserIdentifier: "none",
                    parserVersion: 0
                ),
                accounts: [],
                issues: [
                    ImportIssueFactory.fileError(
                        code: ImportIssueCode.unknownFormat,
                        message: "No brokerage parser matched the file contents."
                    ),
                ]
            )
        }

        let topConfidence = matches.map(\.1.confidence).max() ?? 0
        let top = matches.filter { $0.1.confidence == topConfidence }
        if top.count > 1 {
            return BrokerageImportBatch(
                brokerage: BrokerageIdentity(id: BrokerageID("unknown"), displayName: "Unknown"),
                source: ImportSourceMetadata(
                    originalFilename: fileURL.lastPathComponent,
                    providerTimestamp: nil,
                    importedAt: importedAt,
                    contentFingerprint: CSVSupport.fingerprint(of: data),
                    parserIdentifier: "none",
                    parserVersion: 0
                ),
                accounts: [],
                issues: [
                    ImportIssueFactory.fileError(
                        code: ImportIssueCode.ambiguousFormat,
                        message: "Multiple brokerage parsers matched with equal confidence."
                    ),
                ]
            )
        }

        return try top[0].0.parse(fileURL: fileURL, data: data, importedAt: importedAt)
    }
}
