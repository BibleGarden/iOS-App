import Foundation

enum TestConfig {
    /// Читает API_BASE_URL из BibleGarden/Debug.xcconfig (путь определяется через #filePath).
    /// Xcconfig использует $() для экранирования // — заменяем на пустую строку.
    static var baseURL: String {
        value(forConfigKey: "API_BASE_URL") ?? "https://domain.com"
    }

    static var apiKey: String? {
        value(forConfigKey: "API_KEY")
    }

    /// Строки Debug.xcconfig с раскрытием директив `#include`
    /// (в рабочей копии файл может состоять только из include на локальный конфиг).
    private static func resolvedConfigLines() -> [String] {
        let thisFile = #filePath // compile-time path: .../BibleGardenUITests/Helpers/TestConfig.swift
        let projectRoot = URL(fileURLWithPath: thisFile)
            .deletingLastPathComponent() // Helpers/
            .deletingLastPathComponent() // BibleGardenUITests/
            .deletingLastPathComponent() // project root
        let xcconfigURL = projectRoot
            .appendingPathComponent("BibleGarden")
            .appendingPathComponent("Debug.xcconfig")

        var visited: Set<String> = []
        return expand(url: xcconfigURL, visited: &visited)
    }

    private static func expand(url: URL, visited: inout Set<String>) -> [String] {
        let path = url.standardizedFileURL.path
        guard !visited.contains(path), let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        visited.insert(path)

        var lines: [String] = []
        for rawLine in contents.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#include"), let includeURL = includeURL(from: trimmed, relativeTo: url) {
                lines.append(contentsOf: expand(url: includeURL, visited: &visited))
            } else {
                lines.append(trimmed)
            }
        }
        return lines
    }

    /// Разбирает `#include "путь"` (поддерживаются абсолютные и относительные пути).
    private static func includeURL(from directive: String, relativeTo baseURL: URL) -> URL? {
        guard let openQuote = directive.firstIndex(of: "\""),
              let closeQuote = directive.lastIndex(of: "\""),
              openQuote < closeQuote else { return nil }
        let path = String(directive[directive.index(after: openQuote)..<closeQuote])
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        // $() в xcconfig — пустая переменная для экранирования //
        let cleaned = path.replacingOccurrences(of: "$()", with: "")
        return URL(fileURLWithPath: cleaned, relativeTo: baseURL.deletingLastPathComponent())
    }

    private static func value(forConfigKey prefix: String) -> String? {
        for line in resolvedConfigLines() {
            guard !line.hasPrefix("//"), line.hasPrefix(prefix) else { continue }
            let parts = line.components(separatedBy: "=")
            guard parts.count >= 2 else { continue }
            let raw = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
            // $() в xcconfig — пустая переменная для экранирования //
            return raw.replacingOccurrences(of: "$()", with: "")
        }

        return nil
    }
}
