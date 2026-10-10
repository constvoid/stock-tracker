import SwiftUI

@main
struct StockTrackerApp: App {
    private let dependencies = AppDependencies.makeDeterministicFakes()

    var body: some Scene {
        WindowGroup {
            AppScene(dependencies: dependencies)
        }
    }
}
