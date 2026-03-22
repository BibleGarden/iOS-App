import XCTest

// MARK: - Demo Recording Test
// Скриптованный сценарий для записи App Store preview видео (~30 сек).
// Запуск: xcodebuild test -scheme BibleGarden -destination '...' -only-testing:BibleGardenUITests/DemoRecordingTests/testAppStoreDemo
//
// Параллельно запишите экран:
//   xcrun simctl io booted recordVideo demo.mp4

final class DemoRecordingTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo-recording"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private func pause(_ seconds: TimeInterval = 0.3) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func demoTap(_ element: XCUIElement, prePause: TimeInterval = 0.15, postPause: TimeInterval = 0.3) {
        pause(prePause)
        element.tap()
        pause(postPause)
    }

    private func waitAndTap(_ element: XCUIElement, timeout: TimeInterval = 10, postPause: TimeInterval = 0.3) {
        guard element.waitForExistence(timeout: timeout) else { return }
        demoTap(element, postPause: postPause)
    }

    private func demoTapMultiple(_ element: XCUIElement, times: Int, interval: TimeInterval = 0.2) {
        for _ in 0..<times {
            element.tap()
            pause(interval)
        }
    }

    private func tapHittableText(containing keywords: [String], timeout: TimeInterval = 8, postPause: TimeInterval = 0.4) -> Bool {
        let conditions = keywords.map { "label CONTAINS[c] '\($0)'" }.joined(separator: " OR ")
        let predicate = NSPredicate(format: conditions)
        let matches = app.staticTexts.matching(predicate)

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for i in 0..<matches.count {
                let element = matches.element(boundBy: i)
                if element.exists && element.isHittable {
                    demoTap(element, postPause: postPause)
                    return true
                }
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }

    // MARK: - Main Demo Scenario

    @MainActor
    func testAppStoreDemo() {

        // Сцена 1: Главная → Мультиязычное чтение
        pause(0.8)

        let multiCard = app.buttons["card-multilingual"]
        waitAndTap(multiCard, postPause: 0.5)

        let setupPage = app.otherElements["page-multi-setup"]
        guard setupPage.waitForExistence(timeout: 8) else { return }
        pause(0.3)

        // Сцена 2: Добавляем первый перевод
        let addReadBtn = app.buttons["multi-add-read-step"]
        waitAndTap(addReadBtn, postPause: 0.8)

        let configSave = app.buttons["multi-config-save"]
        waitAndTap(configSave, timeout: 8, postPause: 0.5)

        // Сцена 3: Добавляем паузу
        let addPauseBtn = app.buttons["multi-add-pause-step"]
        waitAndTap(addPauseBtn, postPause: 0.3)

        let pausePlus = app.buttons["multi-pause-plus-1"]
        if pausePlus.waitForExistence(timeout: 3) {
            demoTap(pausePlus, postPause: 0.3)
        }

        // Сцена 4: Добавляем второй перевод
        waitAndTap(addReadBtn, postPause: 0.5)

        let langSection = app.buttons["config-section-language"]
        guard langSection.waitForExistence(timeout: 10) else { return }
        pause(0.3)

        // Язык
        demoTap(langSection, postPause: 0.8)
        let foundEnglish = tapHittableText(containing: ["English"], timeout: 8, postPause: 0.6)
        if !foundEnglish {
            _ = tapHittableText(containing: ["Eng"], timeout: 3, postPause: 0.6)
        }

        // Перевод
        let foundTranslation = tapHittableText(
            containing: ["BSB", "KJV", "ESV", "NIV", "NASB", "NLT", "WEB", "NKJV"],
            timeout: 10, postPause: 0.6
        )
        if !foundTranslation {
            let transSection = app.buttons["config-section-translation"]
            if transSection.waitForExistence(timeout: 3) {
                demoTap(transSection, postPause: 0.8)
                _ = tapHittableText(containing: ["BSB", "KJV", "ESV", "NIV"], timeout: 5, postPause: 0.6)
            }
        }

        // Голос
        let foundVoice = tapHittableText(
            containing: ["Souer", "Bob", "David", "James", "John", "Michael", "Mark"],
            timeout: 10, postPause: 0.4
        )
        if !foundVoice {
            let voiceSection = app.buttons["config-section-voice"]
            if voiceSection.waitForExistence(timeout: 3) {
                demoTap(voiceSection, postPause: 0.8)
                _ = tapHittableText(containing: ["Souer", "Bob"], timeout: 5, postPause: 0.4)
            }
        }

        // Скорость 1.0x → 1.2x
        let speedPlus = app.buttons["config-speed-plus"]
        if !speedPlus.isHittable {
            app.swipeUp()
            pause(0.2)
        }
        if speedPlus.waitForExistence(timeout: 5) {
            demoTapMultiple(speedPlus, times: 2, interval: 0.25)
            pause(0.2)
        }

        // Шрифт 100% → 70%
        let fontMinus = app.buttons["config-font-minus"]
        if fontMinus.waitForExistence(timeout: 5) {
            demoTapMultiple(fontMinus, times: 3, interval: 0.25)
            pause(0.3)
        }

        // Сохраняем второй степ
        let configSave2 = app.buttons["multi-config-save"]
        waitAndTap(configSave2, timeout: 5, postPause: 0.5)

        // Показываем список степов
        pause(0.8)

        // «Сохранить и читать»
        let saveAndRead = app.buttons["multilingual-save-and-read"]
        waitAndTap(saveAndRead, postPause: 0.5)

        // Save-alert — пропускаем
        let skipPredicate = NSPredicate(format: "identifier == 'multi-save-alert' AND (label CONTAINS[c] 'without' OR label CONTAINS[c] 'без' OR label CONTAINS[c] 'Не сохран')")
        let skipBtn = app.buttons.matching(skipPredicate).firstMatch
        if skipBtn.waitForExistence(timeout: 5) {
            demoTap(skipBtn, postPause: 0.5)
        }

        // Страница чтения
        let readingPage = app.otherElements["page-multi-reading"]
        guard readingPage.waitForExistence(timeout: 15) else { return }

        let _ = app.waitForMultiTextContent(timeout: 15)
        pause(0.8)

        // Воспроизведение
        let playPause = app.buttons["multi-play-pause"]
        waitAndTap(playPause, postPause: 1.5)

        // Следующий стих × 3
        let nextUnit = app.buttons["multi-next-unit"]
        if nextUnit.waitForExistence(timeout: 5) && nextUnit.isEnabled {
            demoTap(nextUnit, prePause: 0.3, postPause: 1.5)

            if nextUnit.isEnabled {
                demoTap(nextUnit, prePause: 0.2, postPause: 1.5)
            }

            if nextUnit.isEnabled {
                demoTap(nextUnit, prePause: 0.2, postPause: 1.5)
            }
        }

        // Финал
        pause(1.0)

        if playPause.exists && playPause.isEnabled {
            demoTap(playPause, postPause: 0.5)
        }

        pause(0.5)
    }
}
