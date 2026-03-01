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
                let lang = Locale.current.languageCode ?? "en"
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
                    UserDefaults.standard.set(true, forKey: "isMultilingualReadingActive")
                }
            }
        }

        // Preload WKWebView ahead of time
        preloadedWebView = WKWebView()
        preloadedWebView?.loadHTMLString("", baseURL: nil)

        return true
    }
}
