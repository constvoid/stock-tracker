import Foundation

enum CSVSupport {
    static func parseLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]
            if character == "\"" {
                let next = line.index(after: index)
                if inQuotes, next < line.endIndex, line[next] == "\"" {
                    current.append("\"")
                    index = line.index(after: next)
                    continue
                }
                inQuotes.toggle()
                index = next
                continue
            }
            if character == ",", !inQuotes {
                fields.append(current)
                current = ""
                index = line.index(after: index)
                continue
            }
            current.append(character)
            index = line.index(after: index)
        }
        fields.append(current)
        return fields
    }

    static func fingerprint(of data: Data) -> String {
        // Stable non-cryptographic fingerprint for audit metadata in v1 tests.
        // Production can swap for SHA256 without changing the import contract.
        var hash: UInt64 = 5381
        for byte in data {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash, radix: 16)
    }

    static func parseMoney(_ raw: String) -> Decimal? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != "--" else { return nil }
        text = text.replacingOccurrences(of: "$", with: "")
        text = text.replacingOccurrences(of: ",", with: "")
        text = text.replacingOccurrences(of: "%", with: "")
        return Decimal(string: text)
    }

    static func parseQuantity(_ raw: String) -> Decimal? {
        parseMoney(raw)
    }

    static func parseUSDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.date(from: trimmed)
    }
}
