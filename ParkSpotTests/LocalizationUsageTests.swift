import Foundation
import Testing
@testable import ParkSpot

/// Every key-shaped literal a view passes as copy must exist in the catalog.
/// The other localization tests compare the two built tables with each other; this one catches a key
/// that is used in the code but missing from both (it renders as the raw key, e.g. "park_here").
struct LocalizationUsageTests {
    /// `Text("floor")`, `PillButton("done")`, `String(localized: "unnamed")` …
    /// Blind spot: a key passed through a helper parameter (`control(label: "map")`) is not seen here.
    private static let patterns = [
        #"(?:Text|PillButton|Chip|Label|TextField|Button|alert|confirmationDialog)\(\s*"([a-z][a-z0-9_]*)"#,
        #"String\(localized: "([a-z][a-z0-9_]*)"#,
    ]

    @Test func everyKeyUsedByTheViewsExists() throws {
        let source = URL(fileURLWithPath: #filePath)          // …/ParkSpotTests/LocalizationUsageTests.swift
            .deletingLastPathComponent()                      // …/ParkSpotTests
            .deletingLastPathComponent()                      // repo root
            .appending(path: "ParkSpot")
        let files = try #require(FileManager.default.enumerator(at: source, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
        let en = try #require(strings("en"))

        var missing: Set<String> = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for pattern in Self.patterns {
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(text.startIndex..., in: text)
                for match in regex.matches(in: text, range: range) {
                    guard let keyRange = Range(match.range(at: 1), in: text) else { continue }
                    let key = String(text[keyRange])
                    if en[key] == nil { missing.insert("\(key) (\(file.lastPathComponent))") }
                }
            }
        }
        #expect(missing.isEmpty, "copy keys used but missing from the catalog: \(missing.sorted())")
    }

    private func strings(_ language: String) -> [String: String]? {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return nil }
        return NSDictionary(contentsOf: bundle.bundleURL.appending(path: "Localizable.strings")) as? [String: String]
    }
}
