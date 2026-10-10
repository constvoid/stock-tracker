import Application
import Domain
import Foundation

public struct ETradePortfolioParser: BrokerageFileParser {
    public let identifier = "etrade-portfolio-csv"
    public let version = 1

    public static let brokerage = BrokerageIdentity(
        id: BrokerageID("etrade"),
        displayName: "E*TRADE"
    )

    private let totalTolerance = Decimal(string: "1.00")!

    public init() {}

    public func probe(filePrefix: String) -> ParserProbeResult? {
        let hasSummary = filePrefix.contains("Account Summary")
        let hasView = filePrefix.contains("View Summary")
        let hasDateAcquired = filePrefix.contains("Date Acquired")
        let score =
            (hasSummary ? 0.35 : 0) +
            (hasView ? 0.25 : 0) +
            (hasDateAcquired ? 0.4 : 0)
        guard score >= BrokerageFileParserRegistry.confidenceThreshold else { return nil }
        return ParserProbeResult(confidence: score, brokerage: Self.brokerage)
    }

    public func parse(fileURL: URL, data: Data, importedAt: Date) throws -> BrokerageImportBatch {
        let text = String(decoding: data, as: UTF8.self)
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        var accounts: [ImportedAccountSnapshot] = []
        var fileIssues: [ImportIssue] = []
        var index = 0
        var seenKeys = Set<String>()
        let providerTimestamp = parseGeneratedAt(lines)

        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "Account Summary" {
                let result = parseAccountBlock(lines: lines, startingAt: index)
                index = result.nextIndex
                let keyRef = result.account.sourceAccountKey.externalReference
                if seenKeys.contains(keyRef) {
                    fileIssues.append(
                        ImportIssueFactory.accountError(
                            code: ImportIssueCode.duplicateSourceKey,
                            key: result.account.sourceAccountKey,
                            message: "Duplicate source account key in file."
                        )
                    )
                } else {
                    seenKeys.insert(keyRef)
                    accounts.append(result.account)
                }
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

    private struct AccountBlockResult {
        let account: ImportedAccountSnapshot
        let nextIndex: Int
    }

    private func parseAccountBlock(lines: [String], startingAt start: Int) -> AccountBlockResult {
        var index = start + 1
        var displayName = "Unknown"
        var summaryNet: Decimal?
        var issues: [ImportIssue] = []
        var slices: [ImportedPositionSlice] = []
        var cash = Decimal(0)
        var equityValue = Decimal(0)
        var reportedTotal: Decimal?

        // Summary header + row
        if index < lines.count, lines[index].hasPrefix("Account,") {
            index += 1
        }
        if index < lines.count {
            let summaryFields = CSVSupport.parseLine(lines[index])
            if let name = summaryFields.first, !name.isEmpty {
                displayName = name
            }
            summaryNet = field(summaryFields, at: 1).flatMap(CSVSupport.parseMoney)
            index += 1
        }

        let key = SourceAccountKey(
            brokerageID: Self.brokerage.id,
            externalReference: sourceReference(from: displayName)
        )

        // Skip until positions header
        while index < lines.count {
            let fields = CSVSupport.parseLine(lines[index])
            if fields.first == "Symbol", fields.last == "Date Acquired" || fields.contains("Date Acquired") {
                index += 1
                break
            }
            index += 1
        }

        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("Generated at") || trimmed == "Account Summary" {
                break
            }
            let fields = CSVSupport.parseLine(trimmed)
            let symbol = fields.first ?? ""
            if symbol == "CASH" {
                cash = field(fields, at: 9).flatMap(CSVSupport.parseMoney) ?? 0
                index += 1
                continue
            }
            if symbol == "TOTAL" {
                reportedTotal = field(fields, at: 9).flatMap(CSVSupport.parseMoney)
                index += 1
                break
            }

            let rowNumber = index + 1
            do {
                let parsed = try parsePositionRow(fields: fields, rowNumber: rowNumber, key: key)
                slices.append(parsed.slice)
                issues.append(contentsOf: parsed.issues)
                equityValue += parsed.marketValue
            } catch let failure as RowParseFailure {
                issues.append(failure.issue)
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

        let computed = equityValue + cash
        if let reportedTotal, abs(computed - reportedTotal) > totalTolerance {
            issues.append(
                ImportIssueFactory.accountError(
                    code: ImportIssueCode.totalMismatch,
                    key: key,
                    message: "Account TOTAL differs from computed positions plus cash beyond tolerance."
                )
            )
        } else if let summaryNet, abs(computed - summaryNet) > totalTolerance {
            issues.append(
                ImportIssueFactory.warning(
                    code: ImportIssueCode.roundingMismatch,
                    scope: .account,
                    key: key,
                    message: "Account summary net value differs from computed total within or near tolerance."
                )
            )
        }

        // Summary total gain vs sum of quantity*pricePaid warnings are soft.
        let recomputedCost = slices.reduce(Decimal(0)) { $0 + ($1.quantity * $1.importedUnitCost) }
        let recomputedGain = equityValue - recomputedCost
        if let summaryGainField = optionalSummaryGain(lines: lines, around: start),
           abs(recomputedGain - summaryGainField) > totalTolerance {
            issues.append(
                ImportIssueFactory.warning(
                    code: ImportIssueCode.roundingMismatch,
                    scope: .account,
                    key: key,
                    message: "Displayed total gain differs from quantity times price paid."
                )
            )
        }

        let moneyCash = (try? Money.usd(cash)) ?? (try! Money.usd(0))
        return AccountBlockResult(
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

    private struct ParsedPosition {
        let slice: ImportedPositionSlice
        let marketValue: Decimal
        let issues: [ImportIssue]
    }

    private struct RowParseFailure: Error {
        let issue: ImportIssue
    }

    private func parsePositionRow(
        fields: [String],
        rowNumber: Int,
        key: SourceAccountKey
    ) throws -> ParsedPosition {
        let symbol = field(fields, at: 0) ?? ""
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
        guard let quantity = field(fields, at: 4).flatMap(CSVSupport.parseQuantity) else {
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
        guard let unitCost = field(fields, at: 5).flatMap(CSVSupport.parseMoney) else {
            throw RowParseFailure(
                issue: ImportIssueFactory.rowError(
                    code: ImportIssueCode.malformedUnitCost,
                    key: key,
                    row: rowNumber,
                    message: "Malformed price paid."
                )
            )
        }
        guard let acquiredAt = field(fields, at: 10).flatMap(CSVSupport.parseUSDate) else {
            throw RowParseFailure(
                issue: ImportIssueFactory.rowError(
                    code: ImportIssueCode.unparseableRow,
                    key: key,
                    row: rowNumber,
                    message: "Missing acquisition date on exact lot row."
                )
            )
        }

        let unitPrice = field(fields, at: 1).flatMap(CSVSupport.parseMoney)
        let marketValue = field(fields, at: 9).flatMap(CSVSupport.parseMoney) ?? 0
        let kind: SecurityKind = symbol.uppercased().contains("ETF") ? .etf : .equity
        let canonical = SymbolMapping.canonical(fromNative: symbol)

        let slice = ImportedPositionSlice(
            nativeSymbol: symbol,
            canonicalSymbolCandidate: canonical,
            securityName: nil,
            securityKind: kind,
            quantity: quantity,
            importedUnitPrice: unitPrice,
            importedUnitCost: unitCost,
            acquiredAt: acquiredAt,
            basisKind: .exactAcquisition,
            sourceRow: rowNumber
        )
        return ParsedPosition(slice: slice, marketValue: marketValue, issues: [])
    }

    private func sourceReference(from displayName: String) -> String {
        if let range = displayName.range(of: #"-(\d+)\s*$"#, options: .regularExpression) {
            return String(displayName[range].dropFirst())
        }
        return displayName.lowercased().replacingOccurrences(of: " ", with: "_")
    }

    private func field(_ fields: [String], at index: Int) -> String? {
        guard index < fields.count else { return nil }
        let value = fields[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func parseGeneratedAt(_ lines: [String]) -> Date? {
        guard let line = lines.first(where: { $0.contains("Generated at") }) else { return nil }
        // Generated at Jan 15 2026 10:05 AM ET
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "'Generated at' MMM d yyyy h:mm a 'ET'"
        return formatter.date(from: line.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func optionalSummaryGain(lines: [String], around start: Int) -> Decimal? {
        guard start + 2 < lines.count else { return nil }
        let fields = CSVSupport.parseLine(lines[start + 2])
        return field(fields, at: 2).flatMap(CSVSupport.parseMoney)
    }

    private func abs(_ value: Decimal) -> Decimal {
        value < 0 ? -value : value
    }
}
