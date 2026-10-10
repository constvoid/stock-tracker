import AccountDetailFeature
import Application
import Domain
import HoldingsFeature
import ImportSettingsFeature
import OverviewFeature
import SwiftUI

struct AppScene: View {
    let dependencies: AppDependencies
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedAccountID: AccountID?
    @State private var overviewModel: OverviewViewModel
    @State private var holdingsModel: HoldingsViewModel
    @State private var settingsModel: ImportSettingsViewModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _overviewModel = State(
            initialValue: OverviewViewModel(
                getOverview: dependencies.getOverview,
                refreshMarketData: dependencies.refreshMarketData
            )
        )
        _holdingsModel = State(
            initialValue: HoldingsViewModel(
                getHoldings: dependencies.getHoldings,
                refreshMarketData: dependencies.refreshMarketData
            )
        )
        _settingsModel = State(
            initialValue: ImportSettingsViewModel(
                getSettings: dependencies.getSettings,
                importing: dependencies.brokerageImporting,
                previewImports: dependencies.previewImports,
                commitImports: dependencies.commitImports,
                setVisibility: dependencies.setVisibility,
                resolveStale: dependencies.resolveStale
            )
        )
    }

    var body: some View {
        TabView {
            OverviewRootView(viewModel: overviewModel) { accountID in
                selectedAccountID = accountID
            }
            .tabItem { Label("Overview", systemImage: "chart.line.uptrend.xyaxis") }

            HoldingsRootView(viewModel: holdingsModel) { accountID in
                selectedAccountID = accountID
            }
            .tabItem { Label("Holdings", systemImage: "list.bullet") }

            ImportSettingsRootView(viewModel: settingsModel) { accountID in
                selectedAccountID = accountID
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .sheet(item: $selectedAccountID) { accountID in
            NavigationStack {
                AccountDetailRootView(
                    viewModel: AccountDetailViewModel(
                        accountID: accountID,
                        getAccountDetail: dependencies.getAccountDetail
                    )
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { selectedAccountID = nil }
                    }
                }
            }
        }
        .onChange(of: settingsModel.phase) { _, phase in
            if phase == .result || phase == .idle {
                Task {
                    await overviewModel.load()
                    await holdingsModel.load()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // MKT-003: foreground activation refresh only (no background fetch).
            if phase == .active {
                Task {
                    await overviewModel.refresh()
                    await holdingsModel.refresh()
                }
            }
        }
    }
}

extension AccountID: @retroactive Identifiable {
    public var id: UUID { rawValue }
}
