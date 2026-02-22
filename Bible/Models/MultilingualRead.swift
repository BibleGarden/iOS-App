import Foundation

enum MultilingualStepType: String, Codable {
    case read
    case pause
}

enum MultilingualReadUnit: String, Codable, CaseIterable, DisplayNameProvider {
    case verse
    case paragraph
    case fragment
    case chapter
    
    // helper for localization view
    var localized: String {
        switch self {
        case .verse: return "unit.verse".localized
        case .paragraph: return "unit.paragraph".localized
        case .fragment: return "unit.fragment".localized
        case .chapter: return "unit.chapter".localized
        }
    }
    
    var displayName: String {
        return localized
    }
}

struct MultilingualStep: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: MultilingualStepType
    
    // Read properties
    var languageCode: String = ""
    var languageName: String = "" // Added for UI convenience
    var translationCode: Int = 0
    var translationName: String = ""
    var voiceCode: Int = 0
    var voiceName: String = ""
    var voiceMusic: Bool = false
    var fontIncreasePercent: Double = 100.0
    var playbackSpeed: Double = 1.0
    
    // Pause properties
    var pauseDuration: Double = 2.0

    static func == (lhs: MultilingualStep, rhs: MultilingualStep) -> Bool {
        return lhs.id == rhs.id &&
            lhs.type == rhs.type &&
            lhs.languageCode == rhs.languageCode &&
            lhs.languageName == rhs.languageName &&
            lhs.translationCode == rhs.translationCode &&
            lhs.translationName == rhs.translationName &&
            lhs.voiceCode == rhs.voiceCode &&
            lhs.voiceName == rhs.voiceName &&
            lhs.voiceMusic == rhs.voiceMusic &&
            lhs.pauseDuration == rhs.pauseDuration &&
            lhs.fontIncreasePercent == rhs.fontIncreasePercent &&
            lhs.playbackSpeed == rhs.playbackSpeed
    }

    var languageNameNationalOnly: String {
        let value = languageName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "" }

        // Stored as "National (En)" in config; show only national part in compact UI.
        if let range = value.range(of: " (") {
            return String(value[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }
}

struct MultilingualTemplate: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var steps: [MultilingualStep]
    var unit: MultilingualReadUnit
}

extension Array where Element == MultilingualStep {
    func multilingualCompactDescription() -> String {
        let parts: [String] = self.map { step in
            if step.type == .read {
                let name = step.translationName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { return name }

                let language = step.languageNameNationalOnly
                if !language.isEmpty { return language }

                return "—"
            }

            let pauseValue: String
            if step.pauseDuration.rounded() == step.pauseDuration {
                pauseValue = String(Int(step.pauseDuration))
            } else {
                pauseValue = String(format: "%.1f", step.pauseDuration)
            }

            let pauseTitle = "multilingual.pause".localized.lowercased()
            let seconds = "multilingual.seconds".localized
            return "\(pauseTitle) \(pauseValue) \(seconds)"
        }

        return parts.joined(separator: " • ")
    }
}
