import Application
import Domain
import Foundation

enum ImportIssueCode {
    static let unknownFormat = "unknown_format"
    static let ambiguousFormat = "ambiguous_format"
    static let duplicateSourceKey = "duplicate_source_key"
    static let malformedQuantity = "malformed_quantity"
    static let malformedUnitCost = "malformed_unit_cost"
    static let negativeQuantity = "negative_quantity"
    static let unsupportedSecurity = "unsupported_security"
    static let unparseableRow = "unparseable_row"
    static let totalMismatch = "total_mismatch"
    static let roundingMismatch = "rounding_mismatch"
    static let unknownAcquisitionDate = "unknown_acquisition_date"
    static let marketDataUnavailable = "market_data_unavailable"
}

enum ImportIssueFactory {
    static func fileError(code: String, message: String) -> ImportIssue {
        ImportIssue(
            code: code,
            severity: .error,
            scope: .file,
            redactedMessage: message
        )
    }

    static func accountError(
        code: String,
        key: SourceAccountKey?,
        message: String
    ) -> ImportIssue {
        ImportIssue(
            code: code,
            severity: .error,
            scope: .account,
            accountKey: key,
            redactedMessage: message
        )
    }

    static func rowError(
        code: String,
        key: SourceAccountKey?,
        row: Int,
        message: String
    ) -> ImportIssue {
        ImportIssue(
            code: code,
            severity: .error,
            scope: .row,
            accountKey: key,
            rowNumber: row,
            redactedMessage: message
        )
    }

    static func warning(
        code: String,
        scope: ImportIssueScope,
        key: SourceAccountKey? = nil,
        row: Int? = nil,
        message: String
    ) -> ImportIssue {
        ImportIssue(
            code: code,
            severity: .warning,
            scope: scope,
            accountKey: key,
            rowNumber: row,
            redactedMessage: message
        )
    }
}
