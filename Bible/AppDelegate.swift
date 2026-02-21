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
        }

        // Preload WKWebView ahead of time
        preloadedWebView = WKWebView()
        preloadedWebView?.loadHTMLString("", baseURL: nil)

        return true
    }
}
