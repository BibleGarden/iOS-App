import UIKit
import WebKit

class AppDelegate: NSObject, UIApplicationDelegate {

    var preloadedWebView: WKWebView?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // UI Testing: reset state for clean test runs
        if CommandLine.arguments.contains("--uitesting") {
            if let bundleId = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
            }
            // Override app language if specified (must be before multi-template setup)
            if let langCode = TestingEnvironment.appLanguageOverride {
                UserDefaults.standard.set(langCode, forKey: "app_language")
                switch langCode {
                case "ru":
                    UserDefaults.standard.set("ru", forKey: "language")
                    UserDefaults.standard.set(1, forKey: "translation")
                    UserDefaults.standard.set("SYNO", forKey: "translationName")
                    UserDefaults.standard.set(1, forKey: "voice")
                    UserDefaults.standard.set("Alexander Bondarenko", forKey: "voiceName")
                    UserDefaults.standard.set(true, forKey: "voiceMusic")
                case "uk":
                    UserDefaults.standard.set("uk", forKey: "language")
                    UserDefaults.standard.set(20, forKey: "translation")
                    UserDefaults.standard.set("UBH", forKey: "translationName")
                    UserDefaults.standard.set(130, forKey: "voice")
                    UserDefaults.standard.set("Igor Kozlov", forKey: "voiceName")
                    UserDefaults.standard.set(false, forKey: "voiceMusic")
                default:
                    UserDefaults.standard.set("en", forKey: "language")
                    UserDefaults.standard.set(16, forKey: "translation")
                    UserDefaults.standard.set("BSB", forKey: "translationName")
                    UserDefaults.standard.set(151, forKey: "voice")
                    UserDefaults.standard.set("Bob Souer", forKey: "voiceName")
                    UserDefaults.standard.set(false, forKey: "voiceMusic")
                }
            }
            // Override starting excerpt if specified
            if let excerpt = TestingEnvironment.startExcerptOverride {
                UserDefaults.standard.set(excerpt, forKey: "currentExcerpt")
            }
            // Enable autoProgressAudioEnd if requested
            if TestingEnvironment.autoProgressAudioEnd {
                UserDefaults.standard.set(true, forKey: "autoProgressAudioEnd")
                // Disable autoNextChapter so test can verify progress mark
                // before chapter switches
                UserDefaults.standard.set(false, forKey: "autoNextChapter")
            }
            // Explicitly disable autoNextChapter if requested
            if TestingEnvironment.noAutoNextChapter {
                UserDefaults.standard.set(false, forKey: "autoNextChapter")
            }
            // Override pause settings if specified
            if let pauseType = TestingEnvironment.pauseTypeOverride {
                UserDefaults.standard.set(pauseType, forKey: "pauseType")
            }
            if let pauseBlock = TestingEnvironment.pauseBlockOverride {
                UserDefaults.standard.set(pauseBlock, forKey: "pauseBlock")
            }
            // Override multilingual read unit if specified
            if let unit = TestingEnvironment.multiUnitOverride {
                UserDefaults.standard.set(unit, forKey: "multilingualReadUnit")
            }
            // Setup multilingual template if specified
            if let templateName = TestingEnvironment.multiTemplateOverride {
                let lang = TestingEnvironment.appLanguageOverride ?? Locale.current.languageCode ?? "en"
                var steps: [MultilingualStep] = []

                var primaryStep = MultilingualStep(type: .read)
                switch lang {
                case "ru":
                    primaryStep.languageCode = "ru"
                    primaryStep.translationCode = 1
                    primaryStep.translationName = "SYNO"
                    primaryStep.voiceCode = 1
                    primaryStep.voiceName = "Alexander Bondarenko"
                case "uk":
                    primaryStep.languageCode = "uk"
                    primaryStep.translationCode = 20
                    primaryStep.translationName = "UBH"
                    primaryStep.voiceCode = 130
                    primaryStep.voiceName = "Igor Kozlov"
                default:
                    primaryStep.languageCode = "en"
                    primaryStep.translationCode = 16
                    primaryStep.translationName = "BSB"
                    primaryStep.voiceCode = 151
                    primaryStep.voiceName = "Bob Souer"
                }

                if templateName == "default" {
                    steps = [primaryStep]
                } else if templateName == "two-langs" {
                    let pauseStep = MultilingualStep(type: .pause, pauseDuration: 30.0)
                    var secondStep = MultilingualStep(type: .read)
                    if lang != "en" {
                        secondStep.languageCode = "en"
                        secondStep.translationCode = 16
                        secondStep.translationName = "BSB"
                        secondStep.voiceCode = 151
                        secondStep.voiceName = "Bob Souer"
                    } else {
                        secondStep.languageCode = "ru"
                        secondStep.translationCode = 1
                        secondStep.translationName = "SYNO"
                        secondStep.voiceCode = 1
                        secondStep.voiceName = "Alexander Bondarenko"
                    }
                    steps = [primaryStep, pauseStep, secondStep]
                }

                if !steps.isEmpty, let data = try? JSONEncoder().encode(steps) {
                    UserDefaults.standard.set(data, forKey: "multilingualStepsData")

                    // Also persist as a saved template if requested
                    if TestingEnvironment.multiSaveTemplate {
                        let unit = TestingEnvironment.multiUnitOverride ?? "verse"
                        let readUnit = MultilingualReadUnit(rawValue: unit) ?? .verse
                        let template = MultilingualTemplate(name: "Test Template", steps: steps, unit: readUnit)
                        if let templatesData = try? JSONEncoder().encode([template]) {
                            UserDefaults.standard.set(templatesData, forKey: "multilingualTemplatesData")
                            UserDefaults.standard.set(template.id.uuidString, forKey: "currentTemplateId")
                        }
                        // Stay on setup page for CRUD testing
                        UserDefaults.standard.set(false, forKey: "isMultilingualReadingActive")
                    } else {
                        UserDefaults.standard.set(true, forKey: "isMultilingualReadingActive")
                    }
                }
            }
        }

        // Demo recording: ускоряем анимации чтобы XCUITest не ждал idle долго
        if CommandLine.arguments.contains("--demo-recording") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                for scene in UIApplication.shared.connectedScenes {
                    if let windowScene = scene as? UIWindowScene {
                        for window in windowScene.windows {
                            window.layer.speed = 100
                        }
                    }
                }
            }
        }

        // Preload WKWebView ahead of time
        preloadedWebView = WKWebView()
        preloadedWebView?.loadHTMLString("", baseURL: nil)

        return true
    }
}
