import Foundation

public struct ImportProvenance: Hashable, Sendable, Codable {
    public let parserIdentifier: String
    public let parserVersion: Int
    public let sourceRow: Int?
    public let importedAt: Date

    public init(
        parserIdentifier: String,
        parserVersion: Int,
        sourceRow: Int? = nil,
        importedAt: Date
    ) {
        self.parserIdentifier = parserIdentifier
        self.parserVersion = parserVersion
        self.sourceRow = sourceRow
        self.importedAt = importedAt
    }
}
