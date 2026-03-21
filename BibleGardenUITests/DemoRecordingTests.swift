import XCTest

// MARK: - Demo Recording Test
// Скриптованный сценарий для записи App Store preview видео.
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

    private func pause(_ seconds: TimeInterval = 1.0) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func demoTap(_ element: XCUIElement, prePause: TimeInterval = 0.4, postPause: TimeInterval = 0.8) {
        pause(prePause)
        element.tap()
        pause(postPause)
    }

    private func waitAndTap(_ element: XCUIElement, timeout: TimeInterval = 10, postPause: TimeInterval = 0.8) {
        guard element.waitForExistence(timeout: timeout) else { return }
        demoTap(element, postPause: postPause)
    }

    private func demoTapMultiple(_ element: XCUIElement, times: Int, interval: TimeInterval = 0.3) {
        for _ in 0..<times {
            element.tap()
            pause(interval)
        }
    }

    /// Найти и тапнуть hittable текст по подстроке.
    /// Ищет только элементы на экране (isHittable), чтобы не попасть на off-screen элементы.
    private func tapHittableText(containing keywords: [String], timeout: TimeInterval = 8, postPause: TimeInterval = 1.0) -> Bool {
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
            Thread.sleep(forTimeInterval: 0.3)
        }
        return false
    }

    // MARK: - Main Demo Scenario

    @MainActor
    func testAppStoreDemo() {

        // ============================================================
        // Сцена 1: Главная → Мультиязычное чтение
        // ============================================================
        pause(2.0)

        let multiCard = app.buttons["card-multilingual"]
        waitAndTap(multiCard, postPause: 1.5)

        let setupPage = app.otherElements["page-multi-setup"]
        guard setupPage.waitForExistence(timeout: 8) else { return }
        pause(1.0)

        // ============================================================
        // Сцена 2: Добавляем первый перевод (read step)
        // ============================================================
        let addReadBtn = app.buttons["multi-add-read-step"]
        waitAndTap(addReadBtn, postPause: 2.5)

        // Config sheet — первый степ предзаполнен дефолтами, сразу сохраняем
        let configSave = app.buttons["multi-config-save"]
        waitAndTap(configSave, timeout: 8, postPause: 1.5)

        // ============================================================
        // Сцена 3: Добавляем паузу
        // ============================================================
        let addPauseBtn = app.buttons["multi-add-pause-step"]
        waitAndTap(addPauseBtn, postPause: 1.0)

        // Увеличиваем паузу (2 → 3 сек)
        let pausePlus = app.buttons["multi-pause-plus-1"]
        if pausePlus.waitForExistence(timeout: 3) {
            demoTap(pausePlus, postPause: 0.8)
        }
        pause(0.5)

        // ============================================================
        // Сцена 4: Добавляем второй перевод
        // ============================================================
        waitAndTap(addReadBtn, postPause: 2.0)

        // Ждём полного появления config sheet
        let langSection = app.buttons["config-section-language"]
        guard langSection.waitForExistence(timeout: 10) else { return }
        pause(1.0)

        // 4a. Раскрываем секцию языка
        demoTap(langSection, postPause: 2.0)

        // 4b. Выбираем English (только hittable, чтобы не тапнуть off-screen элемент)
        let foundEnglish = tapHittableText(containing: ["English"], timeout: 8, postPause: 2.0)
        if !foundEnglish {
            // Fallback: если English не нашли, пробуем Eng
            _ = tapHittableText(containing: ["Eng"], timeout: 3, postPause: 2.0)
        }

        // 4c. Секция перевода авто-раскрылась — выбираем перевод
        let foundTranslation = tapHittableText(
            containing: ["BSB", "KJV", "ESV", "NIV", "NASB", "NLT", "WEB", "NKJV"],
            timeout: 10, postPause: 2.0
        )
        if !foundTranslation {
            // Попробуем раскрыть секцию переводов вручную
            let transSection = app.buttons["config-section-translation"]
            if transSection.waitForExistence(timeout: 3) {
                demoTap(transSection, postPause: 2.0)
                _ = tapHittableText(
                    containing: ["BSB", "KJV", "ESV", "NIV"],
                    timeout: 5, postPause: 2.0
                )
            }
        }

        // 4d. Секция голоса авто-раскрылась — выбираем голос
        let foundVoice = tapHittableText(
            containing: ["Souer", "Bob", "David", "James", "John", "Michael", "Mark"],
            timeout: 10, postPause: 1.0
        )
        if !foundVoice {
            let voiceSection = app.buttons["config-section-voice"]
            if voiceSection.waitForExistence(timeout: 3) {
                demoTap(voiceSection, postPause: 2.0)
                _ = tapHittableText(
                    containing: ["Souer", "Bob"],
                    timeout: 5, postPause: 1.0
                )
            }
        }

        // ============================================================
        // Сцена 4e: Увеличиваем скорость 1.0x → 1.2x
        // ============================================================
        // Скроллим к настройкам скорости (ниже аккордеонов)
        let speedPlus = app.buttons["config-speed-plus"]
        if !speedPlus.isHittable {
            app.swipeUp()
            pause(0.5)
        }
        if speedPlus.waitForExistence(timeout: 5) {
            demoTapMultiple(speedPlus, times: 2, interval: 0.5)
            pause(0.5)
        }

        // ============================================================
        // Сцена 4f: Уменьшаем шрифт 100% → 70%
        // ============================================================
        let fontMinus = app.buttons["config-font-minus"]
        if fontMinus.waitForExistence(timeout: 5) {
            demoTapMultiple(fontMinus, times: 3, interval: 0.5)
            pause(0.8)
        }

        // Сохраняем второй степ (кнопка в header — всегда видна)
        let configSave2 = app.buttons["multi-config-save"]
        waitAndTap(configSave2, timeout: 5, postPause: 1.5)

        // ============================================================
        // Сцена 5: Итоговый список степов
        // ============================================================
        pause(2.0)

        // ============================================================
        // Сцена 6: «Сохранить и читать»
        // ============================================================
        let saveAndRead = app.buttons["multilingual-save-and-read"]
        waitAndTap(saveAndRead, postPause: 1.5)

        // Save-alert — пропускаем сохранение шаблона
        // Кнопки внутри alert наследуют identifier "multi-save-alert" от родительского VStack,
        // поэтому ищем по identifier + label (как в тестах #9 и #49)
        let skipPredicate = NSPredicate(format: "identifier == 'multi-save-alert' AND (label CONTAINS[c] 'without' OR label CONTAINS[c] 'без' OR label CONTAINS[c] 'Не сохран')")
        let skipBtn = app.buttons.matching(skipPredicate).firstMatch
        if skipBtn.waitForExistence(timeout: 5) {
            demoTap(skipBtn, postPause: 1.5)
        }

        // ============================================================
        // Сцена 7: Страница чтения
        // ============================================================
        let readingPage = app.otherElements["page-multi-reading"]
        guard readingPage.waitForExistence(timeout: 15) else { return }

        let _ = app.waitForMultiTextContent(timeout: 15)
        pause(2.0)

        // ============================================================
        // Сцена 8: Воспроизведение
        // ============================================================
        let playPause = app.buttons["multi-play-pause"]
        waitAndTap(playPause, postPause: 3.0)

        // ============================================================
        // Сцена 9: Следующий стих × 3
        // ============================================================
        let nextUnit = app.buttons["multi-next-unit"]
        if nextUnit.waitForExistence(timeout: 5) && nextUnit.isEnabled {
            demoTap(nextUnit, prePause: 1.0, postPause: 3.0)

            if nextUnit.isEnabled {
                demoTap(nextUnit, prePause: 0.5, postPause: 3.0)
            }

            if nextUnit.isEnabled {
                demoTap(nextUnit, prePause: 0.5, postPause: 3.0)
            }
        }

        // ============================================================
        // Финал
        // ============================================================
        pause(3.0)

        if playPause.exists && playPause.isEnabled {
            demoTap(playPause, postPause: 2.0)
        }

        pause(2.0)
    }
}
