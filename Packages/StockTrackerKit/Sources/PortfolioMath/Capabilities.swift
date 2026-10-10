import Domain
import Foundation

public enum CapabilityDerivation {
    /// CALC-004: one unknown acquisition date disables tax-term for the account.
    public static func accountCapabilities(slices: [PositionSlice]) -> AccountCapabilities {
        let hasUnknownDate = slices.contains { !$0.hasKnownAcquisitionDate }
        return AccountCapabilities(
            taxTerm: hasUnknownDate || slices.isEmpty
                ? .unavailableMissingAcquisitionDates
                : .available,
            history: hasUnknownDate
                ? .estimatedUnknownAcquisitionDates
                : .reconstructed
        )
    }

    /// Portfolio history quality is the least precise among enabled accounts.
    public static func portfolioHistoryQuality(accounts: [BrokerageAccount]) -> HistoryQuality {
        let enabled = accounts.filter(\.isEnabled)
        if enabled.contains(where: { accountCapabilities(slices: $0.slices).history == .estimatedUnknownAcquisitionDates }) {
            return .estimatedUnknownAcquisitionDates
        }
        return .reconstructed
    }
}
