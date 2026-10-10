import Domain
import Foundation

public enum ProviderSymbolMapping {
    /// Yahoo-style provider symbols use hyphen for share-class dots (`BRK.B` → `BRK-B`).
    public static func yahooSymbol(from canonical: CanonicalSymbol) -> String {
        canonical.rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: ".", with: "-")
    }

    public static func canonical(fromYahoo symbol: String) -> CanonicalSymbol {
        CanonicalSymbol(
            symbol
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
                .replacingOccurrences(of: "-", with: ".")
        )
    }
}
