import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Hashable, DisplayNameProvider {
    case russian = "ru"
    case english = "en"
    case ukrainian = "uk"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .russian: return "Русский"
        case .english: return "English"
        case .ukrainian: return "Українська"
        }
    }
}

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            bundle = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj")
                .flatMap { Bundle(path: $0) } ?? Bundle.main
        }
    }
    
    private var bundle: Bundle = Bundle.main
    
    private init() {
        // Load saved language or use system default
        if let savedLanguage = UserDefaults.standard.string(forKey: "app_language"),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // Detect system language
            let systemLanguage = Locale.current.languageCode ?? "en"
            switch systemLanguage {
            case "ru":
                self.currentLanguage = .russian
            case "uk":
                self.currentLanguage = .ukrainian
            default:
                self.currentLanguage = .english
            }
        }
        
        // Set bundle
        bundle = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj")
            .flatMap { Bundle(path: $0) } ?? Bundle.main
    }
    
    func localizedString(_ key: String, comment: String = "") -> String {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
    
    func localizedString(_ key: String, _ args: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        return String(format: format, arguments: args)
    }
}

// Extension for easy access in SwiftUI
extension String {
    var localized: String {
        return LocalizationManager.shared.localizedString(self)
    }
    
    func localized(_ args: CVarArg...) -> String {
        let format = LocalizationManager.shared.localizedString(self)
        return String(format: format, arguments: args)
    }
}
