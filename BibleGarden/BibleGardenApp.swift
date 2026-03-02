import SwiftUI

@main
struct BibleGardenApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    
    var body: some Scene {
        WindowGroup {
            SkeletonView()
        }
    }
}
