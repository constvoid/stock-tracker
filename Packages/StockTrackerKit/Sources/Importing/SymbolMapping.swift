import Domain
import Foundation

public enum SymbolMapping {
    public static func canonical(fromNative native: String) -> String {
        let trimmed = native.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.replacingOccurrences(of: "/", with: ".")
    }

    public static func providerAlias(fromCanonical canonical: String) -> String {
        canonical.replacingOccurrences(of: ".", with: "-")
    }

    public static func providerAlias(fromNative native: String) -> String {
        providerAlias(fromCanonical: canonical(fromNative: native))
    }
}
