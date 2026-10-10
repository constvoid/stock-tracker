import SwiftUI

public enum PortfolioColor {
    public static let accent = Color.accentColor
    public static let gain = Color.green
    public static let loss = Color.red
    public static let neutral = Color.secondary
    public static let warning = Color.orange
    public static let stale = Color.orange
}

public enum PortfolioSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
}

public enum PortfolioTypography {
    public static let headlineValue = Font.largeTitle.weight(.semibold)
    public static let sectionTitle = Font.title3.weight(.semibold)
    public static let rowTitle = Font.headline
    public static let secondary = Font.subheadline
    public static let caption = Font.caption
}
