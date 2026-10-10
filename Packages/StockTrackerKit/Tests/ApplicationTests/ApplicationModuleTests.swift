import Application
import Testing

@Test func applicationModuleDependsOnCoreTargets() {
    #expect(ApplicationModule.dependsOn.contains("Domain"))
    #expect(ApplicationModule.dependsOn.contains("PortfolioMath"))
}
