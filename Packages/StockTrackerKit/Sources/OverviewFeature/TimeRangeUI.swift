import Domain
import Foundation

enum TimeRangeUI {
    static let pickerOptions: [(id: String, title: String, accessibility: String)] = TimeRange.allCases.map {
        ($0.rawValue, $0.shortTitle, $0.accessibilityTitle)
    }
}
