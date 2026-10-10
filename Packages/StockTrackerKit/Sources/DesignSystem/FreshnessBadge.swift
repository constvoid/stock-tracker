import SwiftUI

public struct FreshnessBadge: View {
    public let text: String
    public let isWarning: Bool

    public init(text: String, isWarning: Bool = false) {
        self.text = text
        self.isWarning = isWarning
    }

    public var body: some View {
        Text(text)
            .font(PortfolioTypography.caption)
            .foregroundStyle(isWarning ? PortfolioColor.warning : PortfolioColor.neutral)
            .accessibilityLabel(text)
    }
}
