import Foundation

enum Config {
    static var baseURL: String {
        guard let url = Bundle.main.infoDictionary?["API_BASE_URL"] as? String, !url.isEmpty else {
            fatalError("API_BASE_URL not found in Info.plist. Make sure Debug.xcconfig / Release.xcconfig exist.")
        }
        return url
    }

    static var apiKey: String {
        guard let key = Bundle.main.infoDictionary?["API_KEY"] as? String, !key.isEmpty else {
            fatalError("API_KEY not found in Info.plist. Make sure Debug.xcconfig / Release.xcconfig exist.")
        }
        return key
    }
}
