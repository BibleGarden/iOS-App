import Foundation

var globalCurrentTranslationIndex: Int = 0

var globalDebug = true

// MARK: - UI Testing support
enum TestingEnvironment {
    static let isUITesting = CommandLine.arguments.contains("--uitesting")
    static let forceLoadError = CommandLine.arguments.contains("--force-load-error")
    static let forceLoadErrorOnce = CommandLine.arguments.contains("--force-load-error-once")
    static let forceNoAudio = CommandLine.arguments.contains("--force-no-audio")
    static let autoProgressAudioEnd = CommandLine.arguments.contains("--auto-progress-audio-end")
    static let noAutoNextChapter = CommandLine.arguments.contains("--no-auto-next-chapter")
    static let pauseTypeOverride: String? = {
        guard let idx = CommandLine.arguments.firstIndex(of: "--pause-type"),
              idx + 1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[idx + 1]
    }()
    static let pauseBlockOverride: String? = {
        guard let idx = CommandLine.arguments.firstIndex(of: "--pause-block"),
              idx + 1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[idx + 1]
    }()
    static let readingProgressSecondsOverride: Double? = {
        guard let idx = CommandLine.arguments.firstIndex(of: "--reading-progress-seconds"),
              idx + 1 < CommandLine.arguments.count,
              let value = Double(CommandLine.arguments[idx + 1]) else { return nil }
        return value
    }()
    static let startExcerptOverride: String? = {
        guard let idx = CommandLine.arguments.firstIndex(of: "--start-excerpt"),
              idx + 1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[idx + 1]
    }()
    static let multiTemplateOverride: String? = {
        guard let idx = CommandLine.arguments.firstIndex(of: "--multi-template"),
              idx + 1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[idx + 1]
    }()
    static let multiUnitOverride: String? = {
        guard let idx = CommandLine.arguments.firstIndex(of: "--multi-unit"),
              idx + 1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[idx + 1]
    }()
    static let multiSaveTemplate = CommandLine.arguments.contains("--multi-save-template")
    static let isDemoRecording = CommandLine.arguments.contains("--demo-recording")
    static let appLanguageOverride: String? = {
        guard let idx = CommandLine.arguments.firstIndex(of: "--app-language"),
              idx + 1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[idx + 1]
    }()
    /// One-shot: consumed after first use
    static var loadErrorOnceConsumed = false
    static var shouldForceLoadError: Bool {
        if forceLoadError { return true }
        if forceLoadErrorOnce && !loadErrorOnceConsumed {
            loadErrorOnceConsumed = true
            return true
        }
        return false
    }
}

let globalBasePadding = 22.0
let globalCornerRadius = 6.0
/// How many seconds earlier to start verse playback (clamped to previous verse end)
let globalVerseEarlyStartSeconds = 0.2

var bibleParts: [String] {
    [
        "bible.part.old".localized,
        "bible.part.new".localized
    ]
}

var bibleHeaders: [Int: String] {
    [
        1: "bible.header.1".localized,
        6: "bible.header.6".localized,
        18: "bible.header.18".localized,
        23: "bible.header.23".localized,
        28: "bible.header.28".localized,
        40: "bible.header.40".localized,
        45: "bible.header.45".localized,
        52: "bible.header.52".localized,
        66: "bible.header.66".localized
    ]
}
