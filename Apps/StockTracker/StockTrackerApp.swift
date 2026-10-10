import SwiftUI

@main
struct StockTrackerApp: App {
    private let dependencies: AppDependencies

    init() {
        do {
            dependencies = try AppDependencies.makeLocal()
        } catch {
            dependencies = AppDependencies.makeDeterministicFakes()
        }
    }

    var body: some Scene {
        WindowGroup {
            AppScene(dependencies: dependencies)
        }
    }
}
