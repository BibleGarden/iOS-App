import XCTest

// MARK: - ReadSettingsDefaultsTests (requires live API)
//
// Чистый первый запуск с русским языком: по умолчанию выбраны перевод
// «Современный русский перевод» (Кулаков, код 11) и диктор
// Никита Семёнов-Прозоровский (код 123).

final class ReadSettingsDefaultsTests: XCTestCase {

    private static let defaultTranslationCode = 11
    private static let defaultVoiceCode = 123

    private var app: XCUIApplication!
    private static var apiChecked = false
    private static var apiAvailable = true

    override func setUpWithError() throws {
        continueAfterFailure = false

        // One-time API health check per test run (with retries)
        if !Self.apiChecked {
            Self.apiChecked = true
            Self.apiAvailable = checkAPIAvailability()
        }

        try XCTSkipUnless(Self.apiAvailable, "API unavailable — skipping reading tests")

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--app-language", "ru"]
        app.launch()
        app.navigateToReadingPage()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Ожидаемые имена берём из API: перевод с кодом 11 и его диктор с кодом 123.
    /// Так тест не зависит от хардкода строк и проверяет именно коды по умолчанию.
    private func expectedDefaultNames() throws -> (translation: String, voice: String) {
        let urlString = "\(TestConfig.baseURL)/api/translations?language=ru"
        guard let url = URL(string: urlString) else {
            XCTFail("Bad URL: \(urlString)")
            return ("", "")
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        if let apiKey = TestConfig.apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }

        let semaphore = DispatchSemaphore(value: 0)
        var body: Data?
        URLSession.shared.dataTask(with: request) { data, _, _ in
            body = data
            semaphore.signal()
        }.resume()
        guard semaphore.wait(timeout: .now() + 30) == .success,
              let data = body,
              let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            XCTFail("Translations API request failed: \(urlString)")
            return ("", "")
        }

        let translation = list.first { ($0["code"] as? Int) == Self.defaultTranslationCode }
        guard let translationName = translation?["name"] as? String else {
            throw XCTSkip("API has no translation with code \(Self.defaultTranslationCode)")
        }
        let voices = (translation?["voices"] as? [[String: Any]]) ?? []
        guard let voiceName = voices.first(where: { ($0["code"] as? Int) == Self.defaultVoiceCode })?["name"] as? String else {
            throw XCTSkip("API has no voice with code \(Self.defaultVoiceCode) for translation \(translationName)")
        }
        return (translationName, voiceName)
    }

    private func openSettings() {
        let settingsBtn = app.buttons["read-settings-button"]
        XCTAssertTrue(settingsBtn.waitForExistence(timeout: 3))
        settingsBtn.tap()
    }

    private func closeSettings() {
        let closeBtn = app.buttons["settings-close"]
        if closeBtn.waitForExistence(timeout: 3) {
            closeBtn.tap()
        } else {
            app.swipeDown()
        }
    }

    // MARK: - Tests

    // Чистый запуск с русским языком: в настройках чтения выбраны
    // перевод Кулакова (BTI, код 11) и диктор Семёнов-Прозоровский (код 123).
    @MainActor
    func testCleanRuLaunchSelectsBTIAndProzorovsky() throws {
        let expected = try expectedDefaultNames()

        // Чипы аудио-панели на странице чтения
        let translationChip = app.buttons["read-translation-chip"]
        XCTAssertTrue(translationChip.waitForExistence(timeout: 5),
                      "Translation chip should exist on the reading page")
        XCTAssertEqual(translationChip.label, expected.translation,
                       "Clean ru launch should default to translation 11 (Kulakov)")

        let voiceChip = app.buttons["read-voice-chip"]
        XCTAssertTrue(voiceChip.waitForExistence(timeout: 5),
                      "Voice chip should exist on the reading page")
        XCTAssertTrue(voiceChip.label.contains(expected.voice),
                      "Clean ru launch should default to voice 123 (Semenov-Prozorovsky), got '\(voiceChip.label)'")

        // Заголовки секций в настройках чтения
        openSettings()

        let transSection = app.otherElements["setup-translation-section"]
        XCTAssertTrue(transSection.waitForExistence(timeout: 5),
                      "Translation settings section should exist")
        // Заголовок аккордеона — кнопка (index 0) с label "Title\nValue"
        let transHeader = transSection.buttons.element(boundBy: 0)
        XCTAssertTrue(transHeader.waitForExistence(timeout: 3))
        XCTAssertTrue(transHeader.label.contains(expected.translation),
                      "Translation settings header should show translation 11 (Kulakov), got '\(transHeader.label)'")

        let voiceSection = app.otherElements["setup-voice-section"]
        XCTAssertTrue(voiceSection.waitForExistence(timeout: 5),
                      "Voice settings section should exist")
        let voiceHeader = voiceSection.buttons.element(boundBy: 0)
        XCTAssertTrue(voiceHeader.waitForExistence(timeout: 3))
        XCTAssertTrue(voiceHeader.label.contains(expected.voice),
                      "Voice settings header should show voice 123 (Semenov-Prozorovsky), got '\(voiceHeader.label)'")

        closeSettings()
    }
}
