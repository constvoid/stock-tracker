import Importing
import Testing

@Test func symbolMappingModuleSurface() {
    #expect(SymbolMapping.canonical(fromNative: "aaax") == "AAAX")
}
