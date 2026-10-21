import XCTest

// MARK: - ReadSettingsDefaultsTests
//
// Первый запуск с русской системной локалью: по умолчанию выбраны перевод
// «Современный русский перевод» ред. Кулакова (BTI, код 11) и диктор
// Никита Семёнов-Прозоровский (код 123), голос без музыки.
// Сохранённый пользователем выбор не сбрасывается при перезапуске без сброса.

final class ReadSettingsDefaultsTests: XCTestCase {

    private static let defaultTranslationName = "BTI"
    private static let defaultVoiceName = "Никита Семёнов-Прозоровский"
    private static let otherTranslationName = "SYNO"
    private static let otherVoiceName = "Александр Бондаренко"

    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Настоящий первый запуск: русская системная локаль, настройки очищены,
    /// проверяемые значения по умолчанию никто предварительно не записывает.
    private func launchCleanFirstRun() {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()
        app.navigateToReadingPage()
    }

    /// Перезапуск того же пользователя без сброса состояния.
    private func relaunchWithoutReset() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()
        app.navigateToReadingPage()
    }

    private func openSettings() {
        let settingsBtn = app.buttons["read-settings-button"]
        XCTAssertTrue(settingsBtn.waitForExistence(timeout: 3))
        settingsBtn.tap()
    }

    private func closeSettings() {
        let closeBtn = app.buttons["settings-close"]
        XCTAssertTrue(closeBtn.waitForExistence(timeout: 5),
                      "Settings close button should exist")
        closeBtn.tap()
    }

    private func waitForReadingPage() {
        let playPause = app.buttons["read-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 8),
                      "Should return to reading page")
    }

    /// Дефолтный выбор на чипах аудио-панели страницы чтения.
    private func assertChips(translation: String, voice: String) {
        let translationChip = app.buttons["read-translation-chip"]
        XCTAssertTrue(translationChip.waitForExistence(timeout: 5),
                      "Translation chip should exist on the reading page")
        XCTAssertEqual(translationChip.label, translation,
                       "Unexpected translation chip label")

        let voiceChip = app.buttons["read-voice-chip"]
        XCTAssertTrue(voiceChip.waitForExistence(timeout: 5),
                      "Voice chip should exist on the reading page")
        XCTAssertTrue(voiceChip.label.contains(voice),
                      "Unexpected voice chip label, got '\(voiceChip.label)'")
    }

    /// Выбранные перевод и диктор в заголовках секций настроек чтения.
    private func assertSettingsHeaders(translation: String, voice: String) {
        openSettings()

        let transSection = app.otherElements["setup-translation-section"]
        XCTAssertTrue(transSection.waitForExistence(timeout: 5),
                      "Translation settings section should exist")
        // Заголовок аккордеона — кнопка (index 0) с label "Title\nValue"
        let transHeader = transSection.buttons.element(boundBy: 0)
        XCTAssertTrue(transHeader.waitForExistence(timeout: 3))
        XCTAssertTrue(transHeader.label.contains(translation),
                      "Translation settings header should show '\(translation)', got '\(transHeader.label)'")

        let voiceSection = app.otherElements["setup-voice-section"]
        XCTAssertTrue(voiceSection.waitForExistence(timeout: 5),
                      "Voice settings section should exist")
        let voiceHeader = voiceSection.buttons.element(boundBy: 0)
        XCTAssertTrue(voiceHeader.waitForExistence(timeout: 3))
        XCTAssertTrue(voiceHeader.label.contains(voice),
                      "Voice settings header should show '\(voice)', got '\(voiceHeader.label)'")

        closeSettings()
    }

    /// voiceMusic из DEBUG-оверлея приложения ("1"/"0").
    private func assertVoiceMusic(_ expected: String, _ message: String) {
        let label = app.staticTexts["debug-voice-music"]
        XCTAssertTrue(label.waitForExistence(timeout: 5),
                      "debug-voice-music label should be published by the app")
        XCTAssertTrue(app.waitForLabel(element: label, toBe: expected, timeout: 5), message)
    }

    /// Дождаться исчезновения элемента (секция диктора сворачивается после выбора).
    private func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 5, _ message: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == 0"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed, message)
    }

    // MARK: - Tests

    // Первый запуск с русской системной локалью: выбраны Кулаков (BTI) и
    // Семёнов-Прозоровский, голос без музыки.
    @MainActor
    func testFirstRuLaunchDefaultsToBTIAndProzorovsky() {
        launchCleanFirstRun()

        assertChips(translation: Self.defaultTranslationName, voice: Self.defaultVoiceName)
        assertVoiceMusic("0", "Russian first launch should default to voice without music (voiceMusic == false)")
        assertSettingsHeaders(translation: Self.defaultTranslationName, voice: Self.defaultVoiceName)
    }

    // Сохранённый пользователем выбор не меняется после перезапуска без сброса.
    @MainActor
    func testSavedChoiceSurvivesRelaunchWithoutReset() {
        launchCleanFirstRun()
        assertChips(translation: Self.defaultTranslationName, voice: Self.defaultVoiceName)

        // Меняем выбор с дефолтного на SYNO + Бондаренко — по названиям, не по индексам.
        openSettings()

        let transSection = app.otherElements["setup-translation-section"]
        XCTAssertTrue(transSection.waitForExistence(timeout: 5))
        transSection.tap()

        // Ждём в раскрывшемся списке именно SYNO по названию
        // (заголовок аккордеона показывает дефолт BTI и не совпадает).
        let synoOption = transSection.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", Self.otherTranslationName)
        ).firstMatch
        XCTAssertTrue(synoOption.waitForExistence(timeout: 5),
                      "SYNO option should appear in the expanded translation list")
        synoOption.tap()

        // После выбора перевода раскрывается секция диктора — ждём её элементы.
        let voiceSection = app.otherElements["setup-voice-section"]
        XCTAssertTrue(voiceSection.waitForExistence(timeout: 5))
        let firstPreviewBtn = app.buttons["settings-voice-preview-0"]
        XCTAssertTrue(firstPreviewBtn.waitForExistence(timeout: 5),
                      "Voice list should appear after selecting a translation")

        // Выбор — тап по имени диктора внутри строки (жест на всей строке,
        // кнопка превью справа не задевается).
        let bondarenkoOption = voiceSection.staticTexts[Self.otherVoiceName]
        XCTAssertTrue(bondarenkoOption.waitForExistence(timeout: 5),
                      "'\(Self.otherVoiceName)' should appear in the voice list")
        bondarenkoOption.tap()

        // Выбор голоса сворачивает секцию — конкретный признак применённого выбора.
        waitForElementToDisappear(firstPreviewBtn,
                                  "Voice section should collapse after selecting a voice")

        closeSettings()
        waitForReadingPage()

        // Выбор применился в этой же сессии
        assertChips(translation: Self.otherTranslationName, voice: Self.otherVoiceName)

        // Перезапуск без сброса — выбор должен сохраниться, дефолт не должен вернуть
        relaunchWithoutReset()
        assertChips(translation: Self.otherTranslationName, voice: Self.otherVoiceName)
        assertVoiceMusic("1", "User-saved voice with music should keep voiceMusic == true after relaunch")
        assertSettingsHeaders(translation: Self.otherTranslationName, voice: Self.otherVoiceName)
    }
}
