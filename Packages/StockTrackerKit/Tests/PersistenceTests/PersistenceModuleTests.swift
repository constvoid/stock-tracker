import Persistence
import SwiftData
import Testing

@Test func schemaVersionIsV1() {
    #expect(PortfolioSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
}
