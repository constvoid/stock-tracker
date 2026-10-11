import Application
import DesignSystem
import Domain
import SwiftUI

/// Large-type, low-interaction iPhone surface for a phone mount (CAR-001).
/// No chart, movers, holdings table, import, or settings controls.
public struct CarGlanceRootView: View {
    @Bindable private var viewModel: CarGlanceViewModel
    private let onClose: (() -> Void)?

    public init(viewModel: CarGlanceViewModel, onClose: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            Group {
                if let total = viewModel.totalValue {
                    loadedContent(total: total)
                } else if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.4)
                } else {
                    VStack(spacing: PortfolioSpacing.md) {
                        Text(viewModel.errorMessage ?? "No portfolio yet")
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                        Text("Import accounts in Settings, then reopen Car Glance.")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.white)
                    .padding(PortfolioSpacing.xl)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let onClose {
                Button("Done", action: onClose)
                    .font(.title3.weight(.semibold))
                    .padding(PortfolioSpacing.lg)
                    .foregroundStyle(.white.opacity(0.85))
                    .accessibilityLabel("Close car glance")
            }
        }
        .preferredColorScheme(.dark)
        #if os(iOS)
        .statusBarHidden(true)
        #endif
        .task { await viewModel.load(refreshQuotes: true) }
        .accessibilityIdentifier("carGlance.root")
    }

    @ViewBuilder
    private func loadedContent(total: Money) -> some View {
        VStack(alignment: .leading, spacing: PortfolioSpacing.xl) {
            Text("Portfolio")
                .font(.title2.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))

            Text(MoneyFormatting.currency(total.amount, compact: true))
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .foregroundStyle(.white)
                .accessibilityLabel("Portfolio value \(MoneyFormatting.currency(total.amount))")

            if let amount = viewModel.todayChangeAmount {
                largeChange(amount: amount.amount, percent: viewModel.todayChangePercent)
            } else {
                Text("Today's change unavailable")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.65))
            }

            Text(freshnessText)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.75))
                .accessibilityLabel(freshnessText)

            if let banner = viewModel.refreshBanner {
                Text(banner)
                    .font(.title3)
                    .foregroundStyle(PortfolioColor.warning)
            }

            Spacer(minLength: PortfolioSpacing.md)

            VStack(alignment: .leading, spacing: PortfolioSpacing.md) {
                ForEach(viewModel.accounts) { account in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.title)
                                .font(.title2.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            if account.isStale {
                                Text("Stale")
                                    .font(.title3)
                                    .foregroundStyle(PortfolioColor.stale)
                            }
                        }
                        Spacer(minLength: PortfolioSpacing.sm)
                        Text(MoneyFormatting.currency(account.value.amount, compact: true))
                            .font(.title.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .foregroundStyle(.white)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(account.title), \(MoneyFormatting.currency(account.value.amount))\(account.isStale ? ", stale" : "")"
                    )
                }
            }
        }
        .padding(.horizontal, PortfolioSpacing.xl)
        .padding(.vertical, PortfolioSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func largeChange(amount: Decimal, percent: Decimal?) -> some View {
        let sign: ChangeSign = amount > 0 ? .up : (amount < 0 ? .down : .flat)
        let color: Color = {
            switch sign {
            case .up: PortfolioColor.gain
            case .down: PortfolioColor.loss
            case .flat: Color.white.opacity(0.7)
            }
        }()
        let symbol: String = {
            switch sign {
            case .up: "arrow.up"
            case .down: "arrow.down"
            case .flat: "minus"
            }
        }()
        let label: String = {
            if let percent {
                return "\(MoneyFormatting.signedCurrency(amount)) (\(MoneyFormatting.signedPercent(percent))) Today"
            }
            return "\(MoneyFormatting.signedCurrency(amount)) Today"
        }()

        return HStack(spacing: PortfolioSpacing.sm) {
            Image(systemName: symbol)
                .font(.largeTitle.weight(.bold))
                .accessibilityHidden(true)
            Text(label)
                .font(.title.weight(.semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var freshnessText: String {
        let base: String
        switch viewModel.freshness {
        case .imported: base = "Imported prices"
        case .cached: base = "Cached prices"
        case .fresh: base = "Live prices"
        case .stale: base = "Stale prices"
        case .unavailable: base = "No price data"
        }
        if let asOf = viewModel.asOf {
            return "\(base) · \(asOf.formatted(date: .omitted, time: .shortened))"
        }
        return base
    }
}

private enum ChangeSign {
    case up, down, flat
}
