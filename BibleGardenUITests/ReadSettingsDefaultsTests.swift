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
        if closeBtn.waitForExistence(timeout: 3) {
            closeBtn.tap()
        } else {
            app.swipeDown()
        }
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

        // Меняем выбор с дефолтного на SYNO + первый голос (Бондаренко)
        openSettings()

        let transSection = app.otherElements["setup-translation-section"]
        XCTAssertTrue(transSection.waitForExistence(timeout: 5))
        transSection.tap()
        Thread.sleep(forTimeInterval: 1) // ждём загрузку списка переводов

        // transSection.buttons: index 0 — заголовок аккордеона, index 1+ — опции.
        // У выбранного перевода внутри кнопки есть Image(checkmark), у остальных — нет.
        let translationButtons = transSection.buttons
        var tappedDifferent = false
        for i in 1..<translationButtons.count {
            let btn = translationButtons.element(boundBy: i)
            guard btn.exists else { continue }
            if btn.images.count == 0 {
                btn.tap()
                tappedDifferent = true
                break
            }
        }
        XCTAssertTrue(tappedDifferent, "Should find a translation different from the default")

        // После выбора перевода раскрывается секция диктора. Голоса выбираются
        // через onTapGesture на HStack (не Button), поэтому тапаем по области
        // имени — левее кнопки превью.
        Thread.sleep(forTimeInterval: 1)
        let previewBtn = app.buttons["settings-voice-preview-0"]
        XCTAssertTrue(previewBtn.waitForExistence(timeout: 5),
                      "Voice list should appear after selecting a translation")
        previewBtn.coordinate(withNormalizedOffset: CGVector(dx: -3.0, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 1)

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
