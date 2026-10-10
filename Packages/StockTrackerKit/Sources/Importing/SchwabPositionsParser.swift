import Application
import Domain
import Foundation

public struct SchwabPositionsParser: BrokerageFileParser {
    public let identifier = "schwab-positions-csv"
    public let version = 1

    public static let brokerage = BrokerageIdentity(
        id: BrokerageID("schwab"),
        displayName: "Charles Schwab"
    )

    private let totalTolerance = Decimal(string: "1.00")!

    public init() {}

    public func probe(filePrefix: String) -> ParserProbeResult? {
        let hasPreamble = filePrefix.contains("Positions for All-Accounts")
        let hasQty = filePrefix.contains("Qty (Quantity)")
        let hasMktVal = filePrefix.contains("Mkt Val (Market Value)")
        let hasAssetType = filePrefix.contains("Asset Type")
        let score =
            (hasPreamble ? 0.35 : 0) +
            (hasQty ? 0.25 : 0) +
            (hasMktVal ? 0.2 : 0) +
            (hasAssetType ? 0.2 : 0)
        guard score >= BrokerageFileParserRegistry.confidenceThreshold else { return nil }
        return ParserProbeResult(confidence: score, brokerage: Self.brokerage)
    }

    public func parse(fileURL: URL, data: Data, importedAt: Date) throws -> BrokerageImportBatch {
        let text = String(decoding: data, as: UTF8.self)
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        let providerTimestamp = parsePreambleTimestamp(lines.first ?? "")
        var accounts: [ImportedAccountSnapshot] = []
        var fileIssues: [ImportIssue] = []
        var index = 0
        var seenKeys = Set<String>()

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.contains("Positions for All-Accounts") {
                index += 1
                continue
            }

            let fields = CSVSupport.parseLine(line)
            if fields.count == 1,
               !fields[0].hasPrefix("Symbol"),
               !fields[0].isEmpty {
                let displayName = fields[0]
                let parseResult = parseAccountSection(
                    displayName: displayName,
                    lines: lines,
                    startingAt: index + 1
                )
                index = parseResult.nextIndex

                let keyRef = sourceReference(from: displayName)
                if seenKeys.contains(keyRef) {
                    fileIssues.append(
                        ImportIssueFactory.accountError(
                            code: ImportIssueCode.duplicateSourceKey,
                            key: SourceAccountKey(brokerageID: Self.brokerage.id, externalReference: keyRef),
                            message: "Duplicate source account key in file."
                        )
                    )
                    continue
                }
                seenKeys.insert(keyRef)
                accounts.append(parseResult.account)
                continue
            }
            index += 1
        }

        return BrokerageImportBatch(
            brokerage: Self.brokerage,
            source: ImportSourceMetadata(
                originalFilename: fileURL.lastPathComponent,
                providerTimestamp: providerTimestamp,
                importedAt: importedAt,
                contentFingerprint: CSVSupport.fingerprint(of: data),
                parserIdentifier: identifier,
                parserVersion: version
            ),
            accounts: accounts,
            issues: fileIssues
        )
    }

    private struct AccountParseResult {
        let account: ImportedAccountSnapshot
        let nextIndex: Int
    }

    private func parseAccountSection(
        displayName: String,
        lines: [String],
        startingAt start: Int
    ) -> AccountParseResult {
        let key = SourceAccountKey(
            brokerageID: Self.brokerage.id,
            externalReference: sourceReference(from: displayName)
        )
        var issues: [ImportIssue] = []
        var slices: [ImportedPositionSlice] = []
        var cash = Decimal(0)
        var equityMarketValue = Decimal(0)
        var reportedTotal: Decimal?
        var index = start
        var sawHeader = false

        while index < lines.count {
            let raw = lines[index]
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                // Blank line ends section only after content started.
                if sawHeader { break }
                index += 1
                continue
            }

            let fields = CSVSupport.parseLine(trimmed)
            if fields.count == 1, !fields[0].hasPrefix("Symbol") {
                // Next account label.
                break
            }

            if fields.first == "Symbol" {
                sawHeader = true
                index += 1
                continue
            }

            let symbol = fields.first ?? ""
            if symbol == "Cash & Cash Investments" {
                if let value = field(fields, at: 7).flatMap(CSVSupport.parseMoney) {
                    cash = value
                }
                index += 1
                continue
            }
            if symbol == "Positions Total" {
                reportedTotal = field(fields, at: 7).flatMap(CSVSupport.parseMoney)
                index += 1
                // End of account section after total.
                index = skipTrailingBlanks(lines, from: index)
                break
            }

            let rowNumber = index + 1
            do {
                let parsed = try parseSecurityRow(fields: fields, rowNumber: rowNumber, key: key)
                slices.append(parsed.slice)
                issues.append(contentsOf: parsed.issues)
                equityMarketValue += parsed.marketValue
            } catch let issue as RowParseFailure {
                issues.append(issue.issue)
            } catch {
                issues.append(
                    ImportIssueFactory.rowError(
                        code: ImportIssueCode.unparseableRow,
                        key: key,
                        row: rowNumber,
                        message: "Holding row could not be parsed."
                    )
                )
            }
            index += 1
        }

        if let reportedTotal {
            let computed = equityMarketValue + cash
            if abs(computed - reportedTotal) > totalTolerance {
                issues.append(
                    ImportIssueFactory.accountError(
                        code: ImportIssueCode.totalMismatch,
                        key: key,
                        message: "Account positions total differs from computed equity plus cash beyond tolerance."
                    )
                )
            } else if computed != reportedTotal {
                issues.append(
                    ImportIssueFactory.warning(
                        code: ImportIssueCode.roundingMismatch,
                        scope: .account,
                        key: key,
                        message: "Account total differs within rounding tolerance."
                    )
                )
            }
        }

        for slice in slices where slice.basisKind == .aggregatePosition {
            issues.append(
                ImportIssueFactory.warning(
                    code: ImportIssueCode.unknownAcquisitionDate,
                    scope: .row,
                    key: key,
                    row: slice.sourceRow,
                    message: "Acquisition date unavailable; slice stored as aggregate position."
                )
            )
        }

        let moneyCash = (try? Money.usd(cash)) ?? (try! Money.usd(0))
        return AccountParseResult(
            account: ImportedAccountSnapshot(
                sourceAccountKey: key,
                displayName: displayName,
                cash: moneyCash,
                slices: slices,
                issues: issues
            ),
            nextIndex: index
        )
    }

    private struct ParsedSecurity {
        let slice: ImportedPositionSlice
        let marketValue: Decimal
        let issues: [ImportIssue]
    }

    private struct RowParseFailure: Error {
        let issue: ImportIssue
    }

    private func parseSecurityRow(
        fields: [String],
        rowNumber: Int,
        key: SourceAccountKey
    ) throws -> ParsedSecurity {
        let symbol = field(fields, at: 0)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !symbol.isEmpty else {
            throw RowParseFailure(
                issue: ImportIssueFactory.rowError(
                    code: ImportIssueCode.unparseableRow,
                    key: key,
                    row: rowNumber,
                    message: "Missing symbol."
                )
            )
        }

        let assetType = field(fields, at: 12) ?? ""
        let kind: SecurityKind
        if assetType.localizedCaseInsensitiveContains("ETF") {
            kind = .etf
        } else if assetType.localizedCaseInsensitiveContains("Equity") {
            kind = .equity
        } else if assetType.localizedCaseInsensitiveContains("Cash") {
            throw RowParseFailure(
                issue: ImportIssueFactory.rowError(
                    code: ImportIssueCode.unsupportedSecurity,
                    key: key,
                    row: rowNumber,
                    message: "Unsupported security type for position row."
                )
            )
        } else {
            // Unknown types with value are errors.
            let mkt = field(fields, at: 7).flatMap(CSVSupport.parseMoney) ?? 0
            if mkt != 0 {
                throw RowParseFailure(
                    issue: ImportIssueFactory.rowError(
                        code: ImportIssueCode.unsupportedSecurity,
                        key: key,
                        row: rowNumber,
                        message: "Unsupported security type with non-zero value."
                    )
                )
            }
            throw RowParseFailure(
                issue: ImportIssueFactory.rowError(
                    code: ImportIssueCode.unsupportedSecurity,
                    key: key,
                    row: rowNumber,
                    message: "Unsupported security type."
                )
            )
        }

        guard let quantity = field(fields, at: 2).flatMap(CSVSupport.parseQuantity) else {
            throw RowParseFailure(
                issue: ImportIssueFactory.rowError(
                    code: ImportIssueCode.malformedQuantity,
                    key: key,
                    row: rowNumber,
                    message: "Malformed quantity."
                )
            )
        }
        if quantity < 0 {
            throw RowParseFailure(
                issue: ImportIssueFactory.rowError(
                    code: ImportIssueCode.negativeQuantity,
                    key: key,
                    row: rowNumber,
                    message: "Negative quantity is out of scope for v1."
                )
            )
        }

        guard let costBasis = field(fields, at: 10).flatMap(CSVSupport.parseMoney), quantity > 0 else {
            throw RowParseFailure(
                issue: ImportIssueFactory.rowError(
                    code: ImportIssueCode.malformedUnitCost,
                    key: key,
                    row: rowNumber,
                    message: "Malformed cost basis."
                )
            )
        }

        let unitCost = costBasis / quantity
        let unitPrice = field(fields, at: 3).flatMap(CSVSupport.parseMoney)
        let marketValue = field(fields, at: 7).flatMap(CSVSupport.parseMoney) ?? 0
        var issues: [ImportIssue] = []

        if let unitPrice {
            let expected = quantity * unitPrice
            if abs(expected - marketValue) > totalTolerance {
                issues.append(
                    ImportIssueFactory.warning(
                        code: ImportIssueCode.roundingMismatch,
                        scope: .row,
                        key: key,
                        row: rowNumber,
                        message: "Market value differs from quantity times price beyond soft tolerance."
                    )
                )
            }
        }

        let canonical = SymbolMapping.canonical(fromNative: symbol)
        let slice = ImportedPositionSlice(
            nativeSymbol: symbol,
            canonicalSymbolCandidate: canonical,
            securityName: field(fields, at: 1),
            securityKind: kind,
            quantity: quantity,
            importedUnitPrice: unitPrice,
            importedUnitCost: unitCost,
            acquiredAt: nil,
            basisKind: .aggregatePosition,
            sourceRow: rowNumber
        )
        return ParsedSecurity(slice: slice, marketValue: marketValue, issues: issues)
    }

    private func sourceReference(from displayName: String) -> String {
        if let range = displayName.range(of: #"\.{3}(\S+)"#, options: .regularExpression) {
            let matched = displayName[range]
            if let suffix = matched.split(separator: ".").last {
                return String(suffix)
            }
        }
        return displayName
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
    }

    private func field(_ fields: [String], at index: Int) -> String? {
        guard index < fields.count else { return nil }
        let value = fields[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func skipTrailingBlanks(_ lines: [String], from index: Int) -> Int {
        var i = index
        while i < lines.count, lines[i].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            i += 1
        }
        return i
    }

    private func parsePreambleTimestamp(_ line: String) -> Date? {
        // Example: Positions for All-Accounts as of 10:00 AM ET, 01/15/2026
        guard let comma = line.range(of: ", ", options: .backwards) else { return nil }
        let datePart = String(line[comma.upperBound...])
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return CSVSupport.parseUSDate(datePart)
    }

    private func abs(_ value: Decimal) -> Decimal {
        value < 0 ? -value : value
    }
}
