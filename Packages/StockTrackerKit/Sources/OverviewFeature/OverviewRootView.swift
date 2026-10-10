import Application
import DesignSystem
import Domain
import PortfolioMath
import SwiftUI

public struct OverviewRootView: View {
    @Bindable private var viewModel: OverviewViewModel
    private let onSelectAccount: (AccountID) -> Void

    public init(
        viewModel: OverviewViewModel,
        onSelectAccount: @escaping (AccountID) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onSelectAccount = onSelectAccount
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let model = viewModel.readModel, !model.isEmpty {
                    loadedContent(model)
                } else if viewModel.isLoading {
                    ProgressView("Loading portfolio…")
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Overview unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    ContentUnavailableView(
                        "No portfolio yet",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Import a brokerage file in Settings to see your overview.")
                    )
                }
            }
            .navigationTitle("Overview")
            .task { await viewModel.load(refreshQuotes: true) }
            .refreshable { await viewModel.refresh() }
        }
        .accessibilityIdentifier("overview.root")
    }

    @ViewBuilder
    private func loadedContent(_ model: PortfolioOverviewReadModel) -> some View {
        List {
            if let banner = viewModel.refreshBanner {
                Section {
                    Text(banner)
                        .font(PortfolioTypography.caption)
                        .foregroundStyle(PortfolioColor.warning)
                        .accessibilityLabel(banner)
                }
            }
            Section {
                VStack(alignment: .leading, spacing: PortfolioSpacing.sm) {
                    Text("Portfolio Value")
                        .font(PortfolioTypography.caption)
                        .foregroundStyle(.secondary)
                    Text(MoneyFormatting.currency(model.totalValue.amount))
                        .font(PortfolioTypography.headlineValue)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    if let amount = model.todayChangeAmount {
                        ChangeIndicator(amount: amount.amount, percent: model.todayChangePercent)
                    } else {
                        Text("Today's change unavailable from imported prices")
                            .font(PortfolioTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    FreshnessBadge(
                        text: freshnessText(model),
                        isWarning: model.freshness == .stale || model.freshness == .imported
                    )
                }
                .padding(.vertical, PortfolioSpacing.xs)
                .accessibilityElement(children: .combine)
            }

            Section("Performance") {
                VStack(alignment: .leading, spacing: PortfolioSpacing.sm) {
                    Text(model.historyQuality == .reconstructed ? "Reconstructed" : "Estimated")
                        .font(PortfolioTypography.secondary)
                        .foregroundStyle(.secondary)
                    Text("Historical chart arrives in a later phase. Current total uses imported prices.")
                        .font(PortfolioTypography.caption)
                        .foregroundStyle(.secondary)
                    if let disclosure = model.disclosure {
                        Text(disclosure)
                            .font(PortfolioTypography.caption)
                            .foregroundStyle(PortfolioColor.warning)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            Section("Movers") {
                if model.movers.gainers.isEmpty, model.movers.losers.isEmpty {
                    Text("Movers need previous-close quotes. Imported prices alone are not enough.")
                        .font(PortfolioTypography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    moverBlock(title: "Gainers", rows: model.movers.gainers)
                    moverBlock(title: "Losers", rows: model.movers.losers)
                }
            }

            Section("Accounts") {
                ForEach(model.brokerages) { brokerage in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { viewModel.isExpanded(brokerage.brokerageID) },
                            set: { _ in viewModel.toggleBrokerage(brokerage.brokerageID) }
                        )
                    ) {
                        ForEach(brokerage.accounts) { account in
                            Button {
                                onSelectAccount(account.accountID)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(account.displayName)
                                        HStack(spacing: PortfolioSpacing.xs) {
                                            if account.isCashOnly {
                                                Text("Cash only")
                                                    .font(PortfolioTypography.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if account.isStale {
                                                Text("Stale")
                                                    .font(PortfolioTypography.caption)
                                                    .foregroundStyle(PortfolioColor.stale)
                                            }
                                        }
                                    }
                                    Spacer()
                                    Text(MoneyFormatting.currency(account.totalValue.amount))
                                        .font(PortfolioTypography.secondary)
                                }
                            }
                            .accessibilityHint("Opens account detail")
                        }
                    } label: {
                        HStack {
                            Text(brokerage.displayName)
                            Spacer()
                            Text(MoneyFormatting.currency(brokerage.totalValue.amount))
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel(
                            "\(brokerage.displayName), \(MoneyFormatting.currency(brokerage.totalValue.amount)), \(viewModel.isExpanded(brokerage.brokerageID) ? "expanded" : "collapsed")"
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func moverBlock(title: String, rows: [MoverRow]) -> some View {
        if !rows.isEmpty {
            Text(title)
                .font(PortfolioTypography.caption)
                .foregroundStyle(.secondary)
            ForEach(rows, id: \.canonicalSymbol.rawValue) { row in
                HStack {
                    Text(row.displaySymbol.rawValue)
                        .font(PortfolioTypography.rowTitle)
                    Spacer()
                    ChangeIndicator(amount: row.dayChange.amount, percent: row.dayChangePercent)
                }
            }
        }
    }

    private func freshnessText(_ model: PortfolioOverviewReadModel) -> String {
        let base: String
        switch model.freshness {
        case .imported: base = "Imported prices"
        case .cached: base = "Cached prices"
        case .fresh: base = "Live prices"
        case .stale: base = "Stale prices"
        case .unavailable: base = "No price data"
        }
        var text = base
        if let asOf = model.asOf {
            text += " · as of \(asOf.formatted(date: .abbreviated, time: .shortened))"
        }
        if model.freshness == .fresh || model.freshness == .stale {
            // Extended-hours inclusion is a provider policy; surface when not regular-only.
            text += " · includes extended hours when available"
        }
        return text
    }
}
