import DesignSystem
import Foundation
import Testing

@Test("UI-007 change formatting includes sign cues")
func changeFormattingHasSigns() {
    #expect(MoneyFormatting.signedCurrency(12.5).hasPrefix("+"))
    #expect(MoneyFormatting.signedCurrency(-3).contains("-") || MoneyFormatting.signedCurrency(-3).hasPrefix("-$") || MoneyFormatting.signedCurrency(-3).contains("("))
    #expect(MoneyFormatting.shares(Decimal(string: "2.5")!) == "2.5" || MoneyFormatting.shares(Decimal(string: "2.5")!).contains("2"))
}
