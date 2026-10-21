import Foundation

enum TestConfig {
    /// Читает API_BASE_URL из BibleGarden/Debug.xcconfig (путь определяется через #filePath).
    /// Xcconfig использует $() для экранирования // — заменяем на пустую строку.
    static var baseURL: String {
        let thisFile = #filePath // compile-time path: .../BibleGardenUITests/Helpers/TestConfig.swift
        let projectRoot = URL(fileURLWithPath: thisFile)
            .deletingLastPathComponent() // Helpers/
            .deletingLastPathComponent() // BibleGardenUITests/
            .deletingLastPathComponent() // project root
        let xcconfigURL = projectRoot
            .appendingPathComponent("BibleGarden")
            .appendingPathComponent("Debug.xcconfig")

        guard let contents = try? String(contentsOf: xcconfigURL, encoding: .utf8) else {
            return "https://domain.com"
        }

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("//"), trimmed.hasPrefix("API_BASE_URL") else { continue }
            let parts = trimmed.components(separatedBy: "=")
            guard parts.count >= 2 else { continue }
            let raw = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
            // $() в xcconfig — пустая переменная для экранирования //
            return raw.replacingOccurrences(of: "$()", with: "")
        }

        return "https://domain.com"
    }
}
