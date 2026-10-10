import Foundation

enum FixtureLoader {
    static func url(_ name: String) throws -> URL {
        let bundle = Bundle.module
        if let url = bundle.url(forResource: name, withExtension: "csv", subdirectory: "Fixtures") {
            return url
        }
        if let url = bundle.url(forResource: name, withExtension: "csv") {
            return url
        }
        throw FixtureError.missing(name)
    }

    enum FixtureError: Error {
        case missing(String)
    }
}
