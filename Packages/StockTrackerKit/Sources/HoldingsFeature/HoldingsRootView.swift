import Application
import DesignSystem
import Domain
import SwiftUI

public struct HoldingsRootView: View {
    @Bindable private var viewModel: HoldingsViewModel
    private let onSelectAccount: (AccountID) -> Void

    public init(
        viewModel: HoldingsViewModel,
        onSelectAccount: @escaping (AccountID) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onSelectAccount = onSelectAccount
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let model = viewModel.readModel, !model.holdings.isEmpty || model.cashTotal.amount > 0 {
                    loadedContent(model)
                } else if viewModel.isLoading {
                    ProgressView("Loading holdings…")
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView("Holdings unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else {
                    ContentUnavailableView(
                        "No holdings yet",
                        systemImage: "list.bullet",
                        description: Text("Import a brokerage file in Settings.")
                    )
                }
            }
            .navigationTitle("Holdings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Picker("Sort", selection: $viewModel.sort) {
                        ForEach(HoldingsViewModel.Sort.allCases) { sort in
                            Text(sort.title).tag(sort)
                        }
                    }
                }
            }
            .task { await viewModel.refresh() }
            .refreshable { await viewModel.refresh() }
        }
        .accessibilityIdentifier("holdings.root")
    }

    @ViewBuilder
    private func loadedContent(_ model: PortfolioHoldingsReadModel) -> some View {
        List {
            if let banner = viewModel.refreshBanner {
                Section {
                    Text(banner)
                        .font(PortfolioTypography.caption)
                        .foregroundStyle(PortfolioColor.warning)
                }
            }
            Section {
                VStack(alignment: .leading, spacing: PortfolioSpacing.sm) {
                    Text("All enabled accounts")
                        .font(PortfolioTypography.caption)
                        .foregroundStyle(.secondary)
                    Text(MoneyFormatting.currency(model.totalValue.amount))
                        .font(PortfolioTypography.headlineValue)
                    if let amount = model.todayChangeAmount {
                        ChangeIndicator(amount: amount.amount, percent: model.todayChangePercent)
                    }
                    FreshnessBadge(
                        text: model.freshness == .imported ? "Imported prices" : model.freshness.rawValue.capitalized,
                        isWarning: model.freshness != .fresh
                    )
                }
                .accessibilityElement(children: .combine)
            }

            Section("Securities") {
                ForEach(viewModel.sortedHoldings) { holding in
                    DisclosureGroup {
                        ForEach(holding.allocations) { allocation in
                            Button {
                                onSelectAccount(allocation.accountID)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(allocation.brokerageName) · \(allocation.accountName)")
                                    Text("\(MoneyFormatting.shares(allocation.quantity.shares)) sh · avg \(MoneyFormatting.currency(allocation.averageCost.amount))")
                                        .font(PortfolioTypography.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: PortfolioSpacing.xs) {
                            HStack {
                                Text(holding.displaySymbol.rawValue)
                                    .font(PortfolioTypography.rowTitle)
                                Spacer()
                                if let value = holding.marketValue {
                                    Text(MoneyFormatting.currency(value.amount))
                                }
                            }
                            if let name = holding.securityName {
                                Text(name)
                                    .font(PortfolioTypography.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            HStack {
                                Text("\(MoneyFormatting.shares(holding.quantity.shares)) sh")
                                if let price = holding.currentPrice {
                                    Text("@ \(MoneyFormatting.currency(price.amount))")
                                }
                                Text("avg \(MoneyFormatting.currency(holding.averageCost.amount))")
                            }
                            .font(PortfolioTypography.caption)
                            .foregroundStyle(.secondary)
                            if let day = holding.dayChange {
                                ChangeIndicator(amount: day.amount, percent: holding.dayChangePercent)
                            }
                        }
                    }
                }
            }

            if model.cashTotal.amount > 0 {
                Section("Cash") {
                    Text(MoneyFormatting.currency(model.cashTotal.amount))
                        .font(PortfolioTypography.rowTitle)
                    ForEach(model.cashByAccount) { row in
                        HStack {
                            Text(row.accountName)
                            Spacer()
                            Text(MoneyFormatting.currency(row.cash.amount))
                                .foregroundStyle(.secondary)
                        }
                        .font(PortfolioTypography.secondary)
                    }
                }
            }
        }
    }
}
