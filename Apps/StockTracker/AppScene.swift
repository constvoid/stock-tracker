import HoldingsFeature
import ImportSettingsFeature
import OverviewFeature
import SwiftUI

struct AppScene: View {
    let dependencies: AppDependencies

    var body: some View {
        TabView {
            OverviewRootView()
                .tabItem { Label("Overview", systemImage: "chart.line.uptrend.xyaxis") }
            HoldingsRootView()
                .tabItem { Label("Holdings", systemImage: "list.bullet") }
            ImportSettingsRootView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .task {
            // Retain the composition root so future use-case wiring has a clear owner.
            _ = dependencies
        }
    }
}
