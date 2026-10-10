import SwiftUI

public enum ChangeSign: Sendable {
    case up
    case down
    case flat
}

public struct ChangeIndicator: View {
    public let sign: ChangeSign
    public let amountText: String
    public let percentText: String?
    public let period: String

    public init(
        amount: Decimal,
        percent: Decimal? = nil,
        period: String = "Today"
    ) {
        if amount > 0 {
            self.sign = .up
        } else if amount < 0 {
            self.sign = .down
        } else {
            self.sign = .flat
        }
        self.amountText = MoneyFormatting.signedCurrency(amount)
        self.percentText = percent.map(MoneyFormatting.signedPercent)
        self.period = period
    }

    public var body: some View {
        HStack(spacing: PortfolioSpacing.xs) {
            Image(systemName: symbolName)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(label)
                .foregroundStyle(color)
                .font(PortfolioTypography.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityPhrase)
    }

    private var symbolName: String {
        switch sign {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .flat: "minus"
        }
    }

    private var color: Color {
        switch sign {
        case .up: PortfolioColor.gain
        case .down: PortfolioColor.loss
        case .flat: PortfolioColor.neutral
        }
    }

    private var label: String {
        if let percentText {
            return "\(amountText) (\(percentText)) \(period)"
        }
        return "\(amountText) \(period)"
    }

    private var accessibilityPhrase: String {
        let direction: String
        switch sign {
        case .up: direction = "up"
        case .down: direction = "down"
        case .flat: direction = "unchanged"
        }
        if let percentText {
            return "\(direction) \(amountText), \(percentText), \(period)"
        }
        return "\(direction) \(amountText), \(period)"
    }
}
