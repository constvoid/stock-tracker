import Application
import DesignSystem
import Domain
import SwiftUI

public struct AccountDetailRootView: View {
    @Bindable private var viewModel: AccountDetailViewModel

    public init(viewModel: AccountDetailViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if let model = viewModel.readModel {
                loadedContent(model)
            } else if viewModel.isLoading {
                ProgressView("Loading account…")
            } else {
                ContentUnavailableView(
                    "Account unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(viewModel.errorMessage ?? "Unknown account")
                )
            }
        }
        .navigationTitle(viewModel.readModel?.displayName ?? "Account")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await viewModel.load() }
        .accessibilityIdentifier("accountDetail.root")
    }

    @ViewBuilder
    private func loadedContent(_ model: AccountDetailReadModel) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: PortfolioSpacing.sm) {
                    Text(model.brokerageName)
                        .font(PortfolioTypography.caption)
                        .foregroundStyle(.secondary)
                    Text(MoneyFormatting.currency(model.totalValue.amount))
                        .font(PortfolioTypography.headlineValue)
                    HStack {
                        labeled("Equity", model.equityValue.amount)
                        labeled("Cash", model.cash.amount)
                    }
                    if let today = model.todayChange {
                        ChangeIndicator(amount: today.amount)
                    }
                    statusChips(model)
                    FreshnessBadge(
                        text: model.freshness == .imported ? "Imported prices" : model.freshness.rawValue.capitalized,
                        isWarning: model.freshness != .fresh
                    )
                }
                .accessibilityElement(children: .combine)
            }

            Section("Performance") {
                PerformanceChartView(
                    points: viewModel.chartPoints,
                    selectedRangeTitle: viewModel.selectedRange.accessibilityTitle,
                    rangeTitles: TimeRange.allCases.map {
                        ($0.rawValue, $0.shortTitle, $0.accessibilityTitle)
                    },
                    selectedRangeID: viewModel.selectedRange.rawValue,
                    qualityLabel: (viewModel.series?.quality ?? model.capabilities.history) == .reconstructed
                        ? "Reconstructed"
                        : "Estimated",
                    disclosure: viewModel.series?.disclosure
                        ?? "Reconstructed from this account's holdings and historical prices.",
                    qualityIsWarning: (viewModel.series?.quality ?? model.capabilities.history)
                        == .estimatedUnknownAcquisitionDates,
                    onSelectRangeID: { id in
                        Task { await viewModel.selectRangeID(id) }
                    }
                )
            }

            Section("Positions") {
                if model.isCashOnly {
                    ContentUnavailableView(
                        "Cash only",
                        systemImage: "banknote",
                        description: Text("This account has cash and no securities.")
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(model.positions) { position in
                        VStack(alignment: .leading, spacing: PortfolioSpacing.xs) {
                            HStack {
                                Text(position.displaySymbol.rawValue)
                                    .font(PortfolioTypography.rowTitle)
                                Spacer()
                                if let value = position.marketValue {
                                    Text(MoneyFormatting.currency(value.amount))
                                }
                            }
                            Text("\(MoneyFormatting.shares(position.quantity.shares)) sh · avg \(MoneyFormatting.currency(position.averageCost.amount))")
                                .font(PortfolioTypography.caption)
                                .foregroundStyle(.secondary)
                            if let gain = position.unrealizedGain {
                                ChangeIndicator(amount: gain.amount, period: "Unrealized")
                            }
                        }
                    }
                }
            }

            Section("Tax term") {
                if model.capabilities.taxTerm == .available {
                    Text("Tax-term reporting is available for this account.")
                        .font(PortfolioTypography.secondary)
                } else {
                    Text("Tax-term data unavailable from this brokerage file")
                        .font(PortfolioTypography.secondary)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func labeled(_ title: String, _ amount: Decimal) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(PortfolioTypography.caption)
                .foregroundStyle(.secondary)
            Text(MoneyFormatting.currency(amount))
                .font(PortfolioTypography.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func statusChips(_ model: AccountDetailReadModel) -> some View {
        HStack(spacing: PortfolioSpacing.sm) {
            Text(model.isEnabled ? "Enabled" : "Hidden")
                .font(PortfolioTypography.caption)
                .foregroundStyle(.secondary)
            if model.isStale {
                Text("Stale")
                    .font(PortfolioTypography.caption)
                    .foregroundStyle(PortfolioColor.stale)
            }
        }
    }
}
