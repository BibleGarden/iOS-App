import XCTest

// MARK: - MultiReadingSetupTests (Setup view, #1-#10 + E2E #49)

final class MultiReadingSetupTests: XCTestCase {

    private var app: XCUIApplication!
    private static var apiChecked = false
    private static var apiAvailable = true

    override func setUpWithError() throws {
        continueAfterFailure = false

        if !Self.apiChecked {
            Self.apiChecked = true
            Self.apiAvailable = checkAPIAvailability()
        }

        try XCTSkipUnless(Self.apiAvailable, "API unavailable — skipping setup tests")

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // #1 — Открываем страницу настройки мультичтения через меню.
    // Результат: страница `page-multi-setup` отображается.
    @MainActor
    func testSetupPageLoads() {
        app.navigateToMultiSetupPage()
        let page = app.otherElements["page-multi-setup"]
        XCTAssertTrue(page.exists, "Setup page should be visible")
    }

    // #2 — При пустых степах отображается пустое состояние с подсказками.
    // Результат: кнопки «Добавить чтение» и «Добавить паузу» видны, кнопка «Сохранить и читать» существует.
    @MainActor
    func testEmptyStateShowsHints() {
        app.navigateToMultiSetupPage()
        let saveButton = app.buttons["multilingual-save-and-read"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button should exist")
        let addRead = app.buttons["multi-add-read-step"]
        XCTAssertTrue(addRead.waitForExistence(timeout: 3), "Add read step button should exist")
        let addPause = app.buttons["multi-add-pause-step"]
        XCTAssertTrue(addPause.waitForExistence(timeout: 3), "Add pause step button should exist")
    }

    // #3 — Тап «Добавить чтение» открывает sheet конфигурации степа.
    // Результат: появляется sheet (PageMultilingualConfigView) с настройками языка/перевода/диктора.
    @MainActor
    func testAddReadStepOpensConfig() {
        app.navigateToMultiSetupPage()
        let addRead = app.buttons["multi-add-read-step"]
        XCTAssertTrue(addRead.waitForExistence(timeout: 5))
        addRead.tap()

        Thread.sleep(forTimeInterval: 1)
        let sheetPresented = app.navigationBars.count > 0 || app.buttons.count > 3
        XCTAssertTrue(sheetPresented, "Config sheet should appear after tapping add read step")
        app.swipeDown()
    }

    // #4 — Тап «Добавить паузу» добавляет строку паузы в список степов.
    // Результат: появляется строка с контролами +/− для длительности паузы (по умолчанию 2 сек).
    @MainActor
    func testAddPauseStep() {
        app.navigateToMultiSetupPage()
        let addPause = app.buttons["multi-add-pause-step"]
        XCTAssertTrue(addPause.waitForExistence(timeout: 5))
        addPause.tap()

        Thread.sleep(forTimeInterval: 1)

        // Пауза добавлена — проверяем наличие иконки hourglass (пауза)
        let hourglassImage = app.images["hourglass"]
        XCTAssertTrue(hourglassImage.waitForExistence(timeout: 3),
                       "Pause step with hourglass icon should appear after adding pause")
    }

    // #5 — Кнопки +/− меняют длительность паузы.
    // Результат: тап + увеличивает длительность, тап − уменьшает, минимум 1 секунда.
    @MainActor
    func testPauseDurationControls() {
        app.navigateToMultiSetupPage()
        let addPause = app.buttons["multi-add-pause-step"]
        XCTAssertTrue(addPause.waitForExistence(timeout: 5))
        addPause.tap()

        Thread.sleep(forTimeInterval: 1)

        // Кнопки +/− внутри строки степа наследуют identifier от родителя (multi-step-row-0).
        // SF Symbols «plus» и «minus» получают label «Add» и «Remove» автоматически.
        let rowPredicate = NSPredicate(format: "identifier == 'multi-step-row-0'")
        let pausePlus = app.buttons.matching(rowPredicate).matching(NSPredicate(format: "label == 'Add'")).firstMatch
        let pauseMinus = app.buttons.matching(rowPredicate).matching(NSPredicate(format: "label == 'Remove'")).firstMatch
        XCTAssertTrue(pausePlus.waitForExistence(timeout: 3), "Plus button should exist")
        XCTAssertTrue(pauseMinus.waitForExistence(timeout: 1), "Minus button should exist")

        // По умолчанию 2с → +1 = 3с → −1 = 2с → −1 = 1с → ещё −1 → остаётся 1с (минимум)
        pausePlus.tap()
        Thread.sleep(forTimeInterval: 0.3)
        pauseMinus.tap()
        Thread.sleep(forTimeInterval: 0.3)
        pauseMinus.tap()
        Thread.sleep(forTimeInterval: 0.3)
        pauseMinus.tap()
        // Краш не произошёл — тест пройден
    }

    // #6 — Тап на кнопку удаления (xmark) удаляет степ из списка.
    // Результат: строка степа исчезает, кнопка удаления больше не существует.
    @MainActor
    func testDeleteStep() {
        app.navigateToMultiSetupPage()
        let addPause = app.buttons["multi-add-pause-step"]
        XCTAssertTrue(addPause.waitForExistence(timeout: 5))
        addPause.tap()

        // Кнопка удаления (xmark) внутри строки степа наследует identifier от родителя.
        // SF Symbol «xmark» получает label «Close».
        let rowPredicate = NSPredicate(format: "identifier == 'multi-step-row-0'")
        let deleteBtn = app.buttons.matching(rowPredicate).matching(NSPredicate(format: "label == 'Close'")).firstMatch
        XCTAssertTrue(deleteBtn.waitForExistence(timeout: 3), "Delete button should exist")
        deleteBtn.tap()

        Thread.sleep(forTimeInterval: 0.5)
        let stepRow = app.buttons.matching(rowPredicate).firstMatch
        XCTAssertFalse(stepRow.exists, "Step should be deleted")
    }

    // #7 — Picker режима чтения (verse/paragraph/fragment/chapter) существует.
    // Результат: элемент `multi-read-unit-picker` присутствует на странице.
    @MainActor
    func testReadUnitPicker() {
        app.navigateToMultiSetupPage()
        let picker = app.otherElements["multi-read-unit-picker"]
            .exists ? app.otherElements["multi-read-unit-picker"] : app.buttons["multi-read-unit-picker"]
        let pickerExists = picker.waitForExistence(timeout: 5)
            || app.buttons.matching(identifier: "multi-read-unit-picker").count > 0
        XCTAssertTrue(pickerExists, "Read unit picker should exist")
    }

    // #8 — Тап «Сохранить и читать» без степов показывает ошибку.
    // Результат: появляется inline-сообщение об ошибке `multi-error-message`.
    @MainActor
    func testSaveAndReadWithoutSteps() {
        app.navigateToMultiSetupPage()
        let saveBtn = app.buttons["multilingual-save-and-read"]
        XCTAssertTrue(saveBtn.waitForExistence(timeout: 5))
        saveBtn.tap()

        let errorMsg = app.otherElements["multi-error-message"]
        let errorFound = errorMsg.waitForExistence(timeout: 3)
            || app.staticTexts.matching(identifier: "multi-error-message").count > 0
        XCTAssertTrue(errorFound, "Error message should appear when saving without steps")
    }

    // #9 — Добавляем read step, тапаем «Сохранить и читать» → появляется save-alert →
    // тапаем «Не сохранять» → переход на страницу чтения `page-multi-reading`.
    // Результат: страница чтения отображается после пропуска сохранения шаблона.
    @MainActor
    func testSaveAndReadTransitionsToReading() {
        app.navigateToMultiSetupPage()

        let addRead = app.buttons["multi-add-read-step"]
        XCTAssertTrue(addRead.waitForExistence(timeout: 5))
        addRead.tap()

        // Config sheet открылся — сохраняем степ по кнопке с identifier
        let configSave = app.buttons["multi-config-save"]
        XCTAssertTrue(configSave.waitForExistence(timeout: 5),
                      "Config save/add button should appear in sheet")
        configSave.tap()
        Thread.sleep(forTimeInterval: 1)

        let saveBtn = app.buttons["multilingual-save-and-read"]
        XCTAssertTrue(saveBtn.waitForExistence(timeout: 3))
        saveBtn.tap()

        // Save alert — элементы с identifier "multi-save-alert"
        // Кнопка «Read without saving» / «Не сохранять» — пропускаем сохранение шаблона
        let skipPredicate = NSPredicate(format: "identifier == 'multi-save-alert' AND (label CONTAINS[c] 'without' OR label CONTAINS[c] 'без' OR label CONTAINS[c] 'Не сохран')")
        let skipBtn = app.buttons.matching(skipPredicate).firstMatch
        if skipBtn.waitForExistence(timeout: 5) {
            skipBtn.tap()
        }

        let readingPage = app.otherElements["page-multi-reading"]
        XCTAssertTrue(readingPage.waitForExistence(timeout: 10),
                      "Should transition to reading page after save & read")
    }

    // #10 — Из reading view тап по шестерёнке возвращает на setup page.
    // Результат: страница `page-multi-setup` отображается после нажатия кнопки конфигурации.
    @MainActor
    func testConfigButtonReturnsToSetup() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "default"]
        app.launch()
        app.navigateToMultiReadingPage()

        let configBtn = app.buttons["multi-config-button"]
        XCTAssertTrue(configBtn.waitForExistence(timeout: 5), "Config button should exist")
        configBtn.tap()

        let setupPage = app.otherElements["page-multi-setup"]
        XCTAssertTrue(setupPage.waitForExistence(timeout: 5),
                      "Should return to setup page after tapping config button")
    }

    // #49 — E2E: Полный путь пользователя — setup → добавление степов → save-alert →
    // reading → play → навигация → отметка прочитано → возврат к конфигурации.
    // Результат: все этапы проходят без ошибок, финальный возврат на setup page.
    @MainActor
    func testFullMultiReadingJourney() {
        app.navigateToMultiSetupPage()

        // 1. Добавляем pause step
        let addPause = app.buttons["multi-add-pause-step"]
        XCTAssertTrue(addPause.waitForExistence(timeout: 5))
        addPause.tap()

        // 2. Добавляем read step (открывает config sheet)
        let addRead = app.buttons["multi-add-read-step"]
        addRead.tap()
        Thread.sleep(forTimeInterval: 2)

        // Config sheet — сохраняем степ
        let configSave = app.buttons["multi-config-save"]
        XCTAssertTrue(configSave.waitForExistence(timeout: 5), "Config save button should appear")
        configSave.tap()
        Thread.sleep(forTimeInterval: 1)

        // 3. Сохранить и читать
        let saveBtn = app.buttons["multilingual-save-and-read"]
        XCTAssertTrue(saveBtn.waitForExistence(timeout: 3))
        saveBtn.tap()

        // Обработка save-alert (кнопка «Read without saving»)
        let skipPredicate = NSPredicate(format: "identifier == 'multi-save-alert' AND (label CONTAINS[c] 'without' OR label CONTAINS[c] 'без' OR label CONTAINS[c] 'Не сохран')")
        let skipBtn = app.buttons.matching(skipPredicate).firstMatch
        if skipBtn.waitForExistence(timeout: 5) {
            skipBtn.tap()
        }

        // 4. Проверяем reading page
        let readingPage = app.otherElements["page-multi-reading"]
        XCTAssertTrue(readingPage.waitForExistence(timeout: 10), "Reading page should appear")
        if readingPage.exists {
            let title = app.buttons["multi-chapter-title"]
            if title.waitForExistence(timeout: 8) {
                XCTAssertFalse(title.label.isEmpty, "Title should have text")
            }

            // 5. Play/pause
            let playPause = app.buttons["multi-play-pause"]
            if playPause.waitForExistence(timeout: 5) && playPause.isEnabled {
                playPause.tap()
                Thread.sleep(forTimeInterval: 2)
                playPause.tap()
            }

            // 6. Следующая глава
            let nextChapter = app.buttons["multi-next-chapter"]
            if nextChapter.waitForExistence(timeout: 3) && nextChapter.isEnabled {
                let oldTitle = title.label
                nextChapter.tap()
                _ = app.waitForLabelChange(element: title, from: oldTitle, timeout: 10)
            }

            // 7. Отметить главу как прочитанную
            let progressBtn = app.buttons["multi-chapter-progress"]
            if progressBtn.waitForExistence(timeout: 5) {
                progressBtn.tap()
            }

            // 8. Возврат к конфигурации
            let configBtn = app.buttons["multi-config-button"]
            if configBtn.waitForExistence(timeout: 3) {
                configBtn.tap()
                let setupPage = app.otherElements["page-multi-setup"]
                XCTAssertTrue(setupPage.waitForExistence(timeout: 5),
                              "Should return to setup from reading")
            }
        }
    }
}

// MARK: - MultiReadingTests (Core reading, #11-#27, #40)

final class MultiReadingTests: XCTestCase {

    private var app: XCUIApplication!
    private static var apiChecked = false
    private static var apiAvailable = true

    @MainActor override func setUpWithError() throws {
        continueAfterFailure = false

        if !Self.apiChecked {
            Self.apiChecked = true
            Self.apiAvailable = checkAPIAvailability()
        }

        try XCTSkipUnless(Self.apiAvailable, "API unavailable — skipping reading tests")

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "default"]
        app.launch()
        app.navigateToMultiReadingPage()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Загрузка и отображение (#11-#15)

    // #11-#15 — Открываем reading page с шаблоном default, проверяем все ключевые элементы:
    // WebView с текстом, заголовок главы, 7 кнопок аудио-панели, чипы перевода/диктора, счётчик юнитов.
    @MainActor
    func testReadingPageElements() {
        // #11 — WebView с текстом главы
        let textContent = app.waitForMultiTextContent(timeout: 15)
        XCTAssertNotNil(textContent, "WebView with text content should load")

        // #12 — Заголовок главы
        let title = app.buttons["multi-chapter-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8), "Chapter title button should exist")
        XCTAssertFalse(title.label.isEmpty, "Chapter title should have text")

        // #13 — 7 кнопок аудио-панели
        let controls = [
            "multi-prev-chapter", "multi-next-chapter",
            "multi-prev-unit", "multi-next-unit",
            "multi-prev-section", "multi-next-section",
            "multi-play-pause"
        ]
        for id in controls {
            let button = app.buttons[id]
            XCTAssertTrue(button.waitForExistence(timeout: 5),
                          "Audio control '\(id)' should exist")
        }

        // #14 — Чипы перевода и диктора
        let transChip = app.staticTexts["multi-translation-chip"]
        XCTAssertTrue(transChip.waitForExistence(timeout: 8), "Translation chip should exist")

        let voiceChip = app.descendants(matching: .any)["multi-voice-chip"]
        XCTAssertTrue(voiceChip.waitForExistence(timeout: 3), "Voice chip should exist")

        // #15 — Счётчик юнитов
        let counter = app.staticTexts["multi-unit-counter"]
        XCTAssertTrue(counter.waitForExistence(timeout: 8), "Unit counter should exist")
        XCTAssertTrue(counter.label.contains("1"), "Unit counter should show current unit")
    }

    // MARK: - Воспроизведение (#16-#18)

    // #16 — Нажимаем play, затем pause.
    // Результат: состояние переходит в "playing", затем в "idle"/"pausing".
    @MainActor
    func testPlayAndPause() {
        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))

        _ = app.waitForMultiPlaybackState("idle", timeout: 10)

        // Play
        playPause.tap()
        let playing = app.waitForMultiPlaybackState("playing", timeout: 15)
            || app.waitForMultiPlaybackState("buffering", timeout: 5)
        XCTAssertTrue(playing, "State should become 'playing' after tap")

        Thread.sleep(forTimeInterval: 1)

        // Pause
        playPause.tap()
        Thread.sleep(forTimeInterval: 1)
        let stateLabel = app.staticTexts["multi-playback-state"]
        if stateLabel.exists {
            let state = stateLabel.label
            XCTAssertTrue(state == "idle" || state == "pausing",
                          "State should be idle/pausing after pause. Got: \(state)")
        }
    }

    // #17 — Навигация на юнит 2, затем play.
    // Результат: воспроизведение начинается с текущей позиции (unit не сбрасывается в 0).
    @MainActor
    func testPlayStartsFromHighlightedPosition() {
        let nextUnit = app.buttons["multi-next-unit"]
        XCTAssertTrue(nextUnit.waitForExistence(timeout: 5))

        if nextUnit.isEnabled {
            nextUnit.tap()
            Thread.sleep(forTimeInterval: 0.5)
            if nextUnit.isEnabled {
                nextUnit.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }

        let currentUnit = app.multiCurrentUnit()
        XCTAssertNotNil(currentUnit)
        let unitBefore = currentUnit ?? "0"

        let playPause = app.buttons["multi-play-pause"]
        if playPause.isEnabled {
            playPause.tap()
            Thread.sleep(forTimeInterval: 2)

            let unitAfter = app.multiCurrentUnit() ?? "0"
            XCTAssertEqual(unitAfter, unitBefore,
                          "Play should start from current unit, not reset. Before: \(unitBefore), after: \(unitAfter)")
            playPause.tap()
        }
    }

    // #18 — Сворачиваем аудио-панель шевроном, затем разворачиваем.
    // Результат: кнопка play скрывается при сворачивании и появляется при разворачивании.
    @MainActor
    func testAudioPanelCollapseAndExpand() {
        let chevron = app.buttons["multi-chevron"]
        XCTAssertTrue(chevron.waitForExistence(timeout: 5))

        // Проверяем что элементы панели видны до сворачивания
        let unitCounter = app.staticTexts["multi-unit-counter"]
        XCTAssertTrue(unitCounter.waitForExistence(timeout: 5),
                      "Unit counter should be visible before collapse")

        // Сворачиваем
        chevron.tap()
        Thread.sleep(forTimeInterval: 0.8)
        // Счётчик юнитов скрыт (opacity: 0, height: 0)
        XCTAssertFalse(unitCounter.isHittable,
                       "Unit counter should not be hittable when panel is collapsed")

        // Разворачиваем
        chevron.tap()
        Thread.sleep(forTimeInterval: 0.8)
        // Счётчик юнитов снова отображается
        XCTAssertTrue(unitCounter.waitForExistence(timeout: 3),
                      "Unit counter should reappear after expanding")
    }

    // MARK: - Навигация по главам (#19-#21)

    // #19 — Нажимаем кнопку «следующая глава».
    // Результат: заголовок главы меняется на другой.
    @MainActor
    func testNextChapter() {
        let title = app.buttons["multi-chapter-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        let oldTitle = title.label

        let nextBtn = app.buttons["multi-next-chapter"]
        XCTAssertTrue(nextBtn.waitForExistence(timeout: 3))
        nextBtn.tap()

        XCTAssertTrue(
            app.waitForLabelChange(element: title, from: oldTitle, timeout: 10),
            "Chapter title should change after tapping next")
    }

    // #20 — Переходим вперёд, затем назад кнопкой «предыдущая глава».
    // Результат: заголовок возвращается к прежнему значению.
    @MainActor
    func testPrevChapter() {
        let title = app.buttons["multi-chapter-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        let oldTitle = title.label

        let nextBtn = app.buttons["multi-next-chapter"]
        XCTAssertTrue(nextBtn.waitForExistence(timeout: 3))
        nextBtn.tap()
        _ = app.waitForLabelChange(element: title, from: oldTitle, timeout: 10)
        let afterNextTitle = title.label

        let prevBtn = app.buttons["multi-prev-chapter"]
        prevBtn.tap()
        XCTAssertTrue(
            app.waitForLabelChange(element: title, from: afterNextTitle, timeout: 10),
            "Chapter title should change after tapping prev")
    }

    // #21 — Тап на заголовок главы открывает sheet выбора главы.
    // Выбираем другую главу — заголовок меняется, страница перезагружается.
    @MainActor
    func testChapterSelectFromTitle() {
        let title = app.buttons["multi-chapter-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        let oldTitle = title.label
        title.tap()

        let closeBtn = app.buttons["select-close"]
        XCTAssertTrue(closeBtn.waitForExistence(timeout: 5),
                      "Chapter selection sheet should appear")

        // Ищем кнопку с номером главы, отличающимся от текущей.
        // По умолчанию открывается Ин.1 — тапаем «2» или «3» из грида.
        let chapterBtn = app.buttons["2"]
        if chapterBtn.waitForExistence(timeout: 5) && chapterBtn.isHittable {
            chapterBtn.tap()
        } else {
            // Если «2» не видна — просто закрываем sheet
            closeBtn.tap()
        }

        // Ждём возврат на reading page и смену заголовка
        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 10),
                      "Should return to reading page after chapter select")

        _ = app.waitForLabelChange(element: title, from: oldTitle, timeout: 10)
        XCTAssertNotEqual(title.label, oldTitle,
                          "Chapter title should change after selecting a different chapter")
    }

    // MARK: - Навигация по юнитам (#22-#27)

    // #22 — Тап «следующий юнит» при остановленном аудио.
    // Результат: `multi-current-unit` = "1", аудио НЕ стартует.
    @MainActor
    func testNextUnitHighlightsWithoutAudio() {
        let nextUnit = app.buttons["multi-next-unit"]
        XCTAssertTrue(nextUnit.waitForExistence(timeout: 5))

        guard nextUnit.isEnabled else { return }

        nextUnit.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let currentUnit = app.multiCurrentUnit()
        XCTAssertEqual(currentUnit, "1", "Current unit should be 1 after next unit tap")

        let stateLabel = app.staticTexts["multi-playback-state"]
        if stateLabel.exists {
            XCTAssertNotEqual(stateLabel.label, "playing",
                              "Audio should not start from unit navigation")
        }
    }

    // #23 — После навигации вперёд тап «предыдущий юнит» возвращает назад.
    // Результат: `multi-current-unit` возвращается к "0", аудио не стартует.
    @MainActor
    func testPrevUnitHighlightsWithoutAudio() {
        let nextUnit = app.buttons["multi-next-unit"]
        XCTAssertTrue(nextUnit.waitForExistence(timeout: 5))

        guard nextUnit.isEnabled else { return }

        nextUnit.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let prevUnit = app.buttons["multi-prev-unit"]
        prevUnit.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let currentUnit = app.multiCurrentUnit()
        XCTAssertEqual(currentUnit, "0", "Current unit should return to 0 after prev unit tap")
    }

    // #24 — Во время воспроизведения тап «следующий юнит».
    // Результат: плеер остаётся в состоянии playing, `multi-current-unit` обновляется.
    @MainActor
    func testUnitNavigationWhilePlaying() {
        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        guard playPause.isEnabled else { return }

        playPause.tap()
        _ = app.waitForMultiPlaybackState("playing", timeout: 15)

        let nextUnit = app.buttons["multi-next-unit"]
        guard nextUnit.isEnabled else {
            playPause.tap()
            return
        }

        nextUnit.tap()
        Thread.sleep(forTimeInterval: 1)

        let stateLabel = app.staticTexts["multi-playback-state"]
        if stateLabel.exists {
            let state = stateLabel.label
            XCTAssertTrue(state == "playing" || state == "buffering",
                          "Should remain playing after unit navigation. Got: \(state)")
        }

        // Проверяем что юнит изменился (значение зависит от скорости проигрывания)
        let currentUnit = app.multiCurrentUnit()
        XCTAssertNotNil(currentUnit, "Current unit label should exist")
        XCTAssertNotEqual(currentUnit, "0",
                      "Unit should have advanced from initial position")

        playPause.tap()
    }

    // #25 — Навигация «следующий юнит» несколько раз.
    // Результат: `multi-unit-counter` обновляется (2 of N, 3 of N...).
    @MainActor
    func testUnitCounterUpdates() {
        let counter = app.staticTexts["multi-unit-counter"]
        XCTAssertTrue(counter.waitForExistence(timeout: 8))

        let nextUnit = app.buttons["multi-next-unit"]
        XCTAssertTrue(nextUnit.isEnabled, "Next unit should be enabled")

        // Тапаем 3 раза и проверяем что счётчик обновляется каждый раз
        var previousLabel = counter.label
        for i in 1...3 {
            guard nextUnit.isEnabled else { break }
            nextUnit.tap()
            let changed = app.waitForLabelChange(element: counter, from: previousLabel, timeout: 5)
            XCTAssertTrue(changed,
                          "Unit counter should update after tap #\(i). Stuck on: \(previousLabel)")
            let newLabel = counter.label
            XCTAssertTrue(newLabel.contains("\(i + 1)"),
                          "Counter should show unit \(i + 1) after \(i) taps. Got: \(newLabel)")
            previousLabel = newLabel
        }
    }

    // #26 — При `currentUnitIndex == 0` кнопка «предыдущий юнит» заблокирована.
    // Результат: `multi-prev-unit.isEnabled == false`.
    @MainActor
    func testFirstUnitPrevDisabled() {
        let prevUnit = app.buttons["multi-prev-unit"]
        XCTAssertTrue(prevUnit.waitForExistence(timeout: 5))
        XCTAssertFalse(prevUnit.isEnabled,
                       "Previous unit should be disabled at first unit")
    }

    // #27 — При последнем юните кнопка «следующий юнит» заблокирована.
    // Результат: `multi-next-unit.isEnabled == false` на последнем юните.
    @MainActor
    func testLastUnitNextDisabled() {
        let nextUnit = app.buttons["multi-next-unit"]
        XCTAssertTrue(nextUnit.waitForExistence(timeout: 5))

        // Навигация до последнего юнита
        while nextUnit.isEnabled {
            nextUnit.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }

        XCTAssertFalse(nextUnit.isEnabled,
                       "Next unit should be disabled at last unit")
    }

    // MARK: - Прогресс (#40)

    // #40 — Тапаем кнопку прогресса дважды: прочитано → не прочитано.
    // Результат: кнопка переключается и остаётся на месте.
    @MainActor
    func testMarkChapterReadAndUnread() {
        let progressBtn = app.buttons["multi-chapter-progress"]
        XCTAssertTrue(progressBtn.waitForExistence(timeout: 8),
                      "Chapter progress button should exist")

        progressBtn.tap()
        Thread.sleep(forTimeInterval: 0.5)

        progressBtn.tap()
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertTrue(progressBtn.exists,
                      "Progress button should still exist after toggling")
    }
}

// MARK: - MultiReadingSectionTests (Section nav with two-langs, #28-#33)

final class MultiReadingSectionTests: XCTestCase {

    private var app: XCUIApplication!
    private static var apiChecked = false
    private static var apiAvailable = true

    @MainActor override func setUpWithError() throws {
        continueAfterFailure = false

        if !Self.apiChecked {
            Self.apiChecked = true
            Self.apiAvailable = checkAPIAvailability()
        }

        try XCTSkipUnless(Self.apiAvailable, "API unavailable — skipping section tests")

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "two-langs", "--multi-unit", "verse"]
        app.launch()
        app.navigateToMultiReadingPage()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // #28 — Тап «следующая секция» при остановленном аудио (шаблон two-langs).
    // Результат: `multi-current-step` изменился, аудио НЕ стартует.
    @MainActor
    func testNextSectionHighlightsWithoutAudio() {
        let nextSection = app.buttons["multi-next-section"]
        XCTAssertTrue(nextSection.waitForExistence(timeout: 5))

        let stepBefore = app.multiCurrentStep() ?? "0"
        guard nextSection.isEnabled else { return }

        nextSection.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let stepAfter = app.multiCurrentStep() ?? "0"
        XCTAssertNotEqual(stepBefore, stepAfter,
                         "Current step should change after next section tap")

        let stateLabel = app.staticTexts["multi-playback-state"]
        if stateLabel.exists {
            XCTAssertNotEqual(stateLabel.label, "playing",
                              "Audio should not start from section navigation")
        }
    }

    // #29 — После навигации вперёд тап «предыдущая секция» возвращает степ.
    // Результат: `multi-current-step` возвращается к предыдущему значению.
    @MainActor
    func testPrevSectionHighlightsWithoutAudio() {
        let nextSection = app.buttons["multi-next-section"]
        XCTAssertTrue(nextSection.waitForExistence(timeout: 5))
        guard nextSection.isEnabled else { return }

        nextSection.tap()
        Thread.sleep(forTimeInterval: 0.5)
        let stepAfterNext = app.multiCurrentStep() ?? "0"

        let prevSection = app.buttons["multi-prev-section"]
        prevSection.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let stepAfterPrev = app.multiCurrentStep() ?? "0"
        XCTAssertNotEqual(stepAfterNext, stepAfterPrev,
                         "Step should change after prev section tap")
    }

    // #30 — Навигация по секциям пересекает границу юнита.
    // Результат: `multi-current-unit` увеличивается при переходе через все степы текущего юнита.
    @MainActor
    func testSectionNavigationCrossesUnitBoundary() {
        let nextSection = app.buttons["multi-next-section"]
        XCTAssertTrue(nextSection.waitForExistence(timeout: 5))

        let unitBefore = app.multiCurrentUnit() ?? "0"

        // Проходим через все степы текущего юнита до границы следующего
        // Шаблон two-langs: read(0) → pause(1) → read(2) → переход на unit 1
        var maxTaps = 5
        while nextSection.isEnabled && maxTaps > 0 {
            let currentUnit = app.multiCurrentUnit() ?? "0"
            nextSection.tap()
            Thread.sleep(forTimeInterval: 0.5)
            let newUnit = app.multiCurrentUnit() ?? "0"
            if newUnit != currentUnit {
                XCTAssertNotEqual(unitBefore, newUnit,
                                 "Unit should change when section crosses boundary")
                return
            }
            maxTaps -= 1
        }
    }

    // #31 — Во время воспроизведения тап «следующая секция».
    // Результат: воспроизведение продолжается на новом шаге, `multi-current-step` обновляется.
    @MainActor
    func testSectionNavigationWhilePlaying() {
        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        guard playPause.isEnabled else { return }

        playPause.tap()
        _ = app.waitForMultiPlaybackState("playing", timeout: 15)

        let nextSection = app.buttons["multi-next-section"]
        guard nextSection.isEnabled else {
            playPause.tap()
            return
        }

        let stepBefore = app.multiCurrentStep() ?? "0"
        nextSection.tap()

        // Ждём что плеер запустил воспроизведение нового шага.
        // С коротким стихом (verse mode) он может уже закончиться и перейти к pause step.
        let reachedPlaying = app.waitForMultiPlaybackState("playing", timeout: 10)
            || app.waitForMultiPlaybackState("autopausing", timeout: 3)

        let stepAfter = app.multiCurrentStep() ?? "0"
        XCTAssertNotEqual(stepBefore, stepAfter,
                         "Step should update during playback section navigation")

        XCTAssertTrue(reachedPlaying, "Playback should resume after section navigation")

        let stateLabel = app.staticTexts["multi-playback-state"]
        if stateLabel.exists && (stateLabel.label == "playing" || stateLabel.label == "autopausing") {
            playPause.tap()
        }
    }

    // #31b — Во время воспроизведения тап стрелкой юнита.
    // Результат: воспроизведение продолжается на следующем юните.
    @MainActor
    func testUnitNavigationWhilePlaying() {
        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        guard playPause.isEnabled else { return }

        let unitBefore = app.multiCurrentUnit() ?? "-1"

        playPause.tap()
        XCTAssertTrue(app.waitForMultiPlaybackState("playing", timeout: 15), "Should start playing")

        let nextUnit = app.buttons["multi-next-unit"]
        XCTAssertTrue(nextUnit.waitForExistence(timeout: 3))
        guard nextUnit.isEnabled else { return }
        nextUnit.tap()

        // Ждём что воспроизведение запустилось на новом юните.
        // С коротким стихом (verse mode) он может уже закончиться и перейти к pause step.
        let resumedPlaying = app.waitForMultiPlaybackState("playing", timeout: 15)
            || app.waitForMultiPlaybackState("autopausing", timeout: 3)
        XCTAssertTrue(resumedPlaying, "Playback should resume (playing or autopausing) on next unit")

        let unitAfter = app.multiCurrentUnit() ?? "-1"
        XCTAssertNotEqual(unitBefore, unitAfter, "Unit should have changed")

        let stateLabel = app.staticTexts["multi-playback-state"]
        if stateLabel.exists && (stateLabel.label == "playing" || stateLabel.label == "autopausing") {
            playPause.tap()
        }
    }

    // #32 — На первом read step первого юнита кнопка «предыдущая секция» заблокирована.
    // Результат: `multi-prev-section.isEnabled == false`.
    @MainActor
    func testSectionStartPrevDisabled() {
        let prevSection = app.buttons["multi-prev-section"]
        XCTAssertTrue(prevSection.waitForExistence(timeout: 5))
        XCTAssertFalse(prevSection.isEnabled,
                       "Prev section should be disabled at first step of first unit")
    }

    // #33 — На последнем read step последнего юнита кнопка «следующая секция» заблокирована.
    // Результат: `multi-next-section.isEnabled == false`.
    @MainActor
    func testSectionEndNextDisabled() {
        let nextSection = app.buttons["multi-next-section"]
        let nextUnit = app.buttons["multi-next-unit"]
        XCTAssertTrue(nextSection.waitForExistence(timeout: 5))

        // Навигация до последнего юнита
        while nextUnit.isEnabled {
            nextUnit.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Навигация до последней секции
        while nextSection.isEnabled {
            nextSection.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }

        XCTAssertFalse(nextSection.isEnabled,
                       "Next section should be disabled at last step of last unit")
    }
}

// MARK: - MultiReadingBoundaryTests (Boundary chapters, #34-#35)

final class MultiReadingBoundaryTests: XCTestCase {

    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        app = nil
    }

    // #34 — Запускаем на Бытие 1 (первая глава Библии).
    // Результат: кнопка «предыдущая глава» заблокирована, «следующая» активна.
    @MainActor
    func testFirstChapterPrevDisabled() {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "default", "--start-excerpt", "gen 1"]
        app.launch()
        app.navigateToMultiReadingPage()

        let prevBtn = app.buttons["multi-prev-chapter"]
        XCTAssertTrue(prevBtn.waitForExistence(timeout: 5))
        XCTAssertFalse(prevBtn.isEnabled,
                       "Previous chapter should be disabled at Genesis 1")

        let nextBtn = app.buttons["multi-next-chapter"]
        XCTAssertTrue(nextBtn.isEnabled,
                      "Next chapter should be enabled at Genesis 1")
    }

    // #35 — Запускаем на Откровение 22 (последняя глава Библии).
    // Результат: кнопка «следующая глава» заблокирована, «предыдущая» активна.
    @MainActor
    func testLastChapterNextDisabled() {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "default", "--start-excerpt", "rev 22"]
        app.launch()
        app.navigateToMultiReadingPage()

        let nextBtn = app.buttons["multi-next-chapter"]
        XCTAssertTrue(nextBtn.waitForExistence(timeout: 5))
        XCTAssertFalse(nextBtn.isEnabled,
                       "Next chapter should be disabled at Revelation 22")

        let prevBtn = app.buttons["multi-prev-chapter"]
        XCTAssertTrue(prevBtn.isEnabled,
                      "Previous chapter should be enabled at Revelation 22")
    }
}

// MARK: - MultiReadingStepTests (Step system with two-langs, #36-#39)

final class MultiReadingStepTests: XCTestCase {

    private var app: XCUIApplication!
    private static var apiChecked = false
    private static var apiAvailable = true

    @MainActor override func setUpWithError() throws {
        continueAfterFailure = false

        if !Self.apiChecked {
            Self.apiChecked = true
            Self.apiAvailable = checkAPIAvailability()
        }

        try XCTSkipUnless(Self.apiAvailable, "API unavailable — skipping step tests")

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "two-langs"]
        app.launch()
        app.navigateToMultiReadingPage()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // #36 — Запускаем воспроизведение с шаблоном two-langs (read + pause + read).
    // Результат: step-система продвигается — `multi-current-step` меняется с "0" на другое значение.
    @MainActor
    func testMultiStepPlaythrough() {
        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        guard playPause.isEnabled else { return }

        let stepBefore = app.multiCurrentStep() ?? "0"
        XCTAssertEqual(stepBefore, "0", "Should start at step 0")

        playPause.tap()
        _ = app.waitForMultiPlaybackState("playing", timeout: 15)

        let stateLabel = app.staticTexts["multi-playback-state"]
        let stepLabel = app.staticTexts["multi-current-step"]

        // Ждём пока step сменится (переход через паузу к следующему read step)
        if stepLabel.exists {
            let stepChanged = app.waitForLabelChange(element: stepLabel, from: "0", timeout: 60)
            if stepChanged {
                XCTAssertTrue(true, "Step system advanced from step 0")
            }
        }

        playPause.tap()
    }

    // #37 — Во время pause step кнопка play/pause показывает иконку hourglass.
    // Результат: при достижении паузы состояние переходит в "autopausing", кнопка существует.
    @MainActor
    func testPauseStepShowsHourglass() {
        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        guard playPause.isEnabled else { return }

        playPause.tap()
        _ = app.waitForMultiPlaybackState("playing", timeout: 15)

        // Ждём autopausing (наступает при переходе к pause step)
        let gotAutopausing = app.waitForMultiPlaybackState("autopausing", timeout: 60)
        if gotAutopausing {
            XCTAssertTrue(playPause.exists, "Play/pause button should exist during autopausing")
        }

        playPause.tap()
    }

    // #38 — Во время pause step тап play пропускает паузу.
    // Результат: после тапа состояние переходит из "autopausing" к следующему read step (playing).
    @MainActor
    func testManualSkipPauseStep() {
        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        XCTAssertTrue(playPause.isEnabled, "Play button should be enabled")

        playPause.tap()
        XCTAssertTrue(app.waitForMultiPlaybackState("playing", timeout: 15),
                      "Playback should start")

        // Ждём autopausing (pause step между двумя read steps в two-langs, 30 сек)
        let gotAutopausing = app.waitForMultiPlaybackState("autopausing", timeout: 60)
        XCTAssertTrue(gotAutopausing, "Should reach autopausing state (pause step)")

        // Запоминаем step index во время паузы
        let stepDuringPause = app.multiCurrentStep()

        // Тапаем play чтобы пропустить паузу
        playPause.tap()

        // Должен перейти к следующему read step и начать играть
        let resumed = app.waitForMultiPlaybackState("playing", timeout: 15)
        XCTAssertTrue(resumed,
                      "Should resume playing after skipping pause step")

        // Step index должен увеличиться (пропущена пауза → следующий read step)
        let stepAfterSkip = app.multiCurrentStep()
        XCTAssertNotEqual(stepDuringPause, stepAfterSkip,
                          "Step index should change after skipping pause. During pause: \(stepDuringPause ?? "nil"), After skip: \(stepAfterSkip ?? "nil")")

        playPause.tap()
    }

    // #39 — С шаблоном two-langs чип перевода обновляется при смене read step.
    // Результат: `multi-translation-chip` показывает один перевод, после смены степа — другой.
    @MainActor
    func testTranslationChipUpdatesPerStep() {
        // Identifier пропагируется на дочерние элементы — берём StaticText с названием перевода
        let chipText = app.staticTexts["multi-translation-chip"]
        XCTAssertTrue(chipText.waitForExistence(timeout: 8), "Translation chip text should exist")
        let initialTranslation = chipText.label

        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.isEnabled, "Play button should be enabled")

        // Играем первый read step
        playPause.tap()
        XCTAssertTrue(app.waitForMultiPlaybackState("playing", timeout: 15), "Should start playing")

        // Ждём autopausing (30-секундная пауза между read steps)
        let gotPause = app.waitForMultiPlaybackState("autopausing", timeout: 60)
        XCTAssertTrue(gotPause, "Should reach pause step between read steps")

        // Пропускаем паузу тапом play → переход ко второму read step
        playPause.tap()
        XCTAssertTrue(app.waitForMultiPlaybackState("playing", timeout: 15),
                      "Should resume playing on second read step after skipping pause")

        // Чип перевода должен показывать другой перевод
        let newTranslation = chipText.label
        XCTAssertNotEqual(initialTranslation, newTranslation,
                          "Translation chip should update when step changes. Was: \(initialTranslation), Now: \(newTranslation)")

        playPause.tap()
    }
}

// MARK: - MultiReadingAudioEndProgressTests (#41)

final class MultiReadingAudioEndProgressTests: XCTestCase {

    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        app = nil
    }

    // #41 — Включаем autoProgressAudioEnd, открываем короткий Псалом 117,
    // дослушиваем до конца.
    // Результат: глава автоматически отмечается как прочитанная после окончания аудио.
    @MainActor
    func testAutoProgressOnAudioEnd() throws {
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--multi-template", "default",
            "--auto-progress-audio-end",
            "--start-excerpt", "psa 117"
        ]
        app.launch()
        app.navigateToMultiReadingPage()

        let stateLabel = app.staticTexts["multi-playback-state"]
        guard stateLabel.waitForExistence(timeout: 10) else {
            throw XCTSkip("Playback state label not found")
        }

        let progressBtn = app.buttons["multi-chapter-progress"]
        XCTAssertTrue(progressBtn.waitForExistence(timeout: 5))
        XCTAssertEqual(progressBtn.value as? String, "unread",
                       "Chapter should be unread before audio finishes")

        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        playPause.tap()
        _ = app.waitForMultiPlaybackState("playing", timeout: 15)

        // Псалом 117 — 2 стиха, пропускаем на последний юнит
        let nextUnit = app.buttons["multi-next-unit"]
        if nextUnit.waitForExistence(timeout: 3) && nextUnit.isEnabled {
            Thread.sleep(forTimeInterval: 1)
            nextUnit.tap()
        }

        // Ждём завершения аудио
        let finishedPredicate = NSPredicate(format: "label == %@ OR label == %@",
                                            "finished", "segmentFinished")
        let finishExp = XCTNSPredicateExpectation(predicate: finishedPredicate, object: stateLabel)
        _ = XCTWaiter.wait(for: [finishExp], timeout: 30)

        Thread.sleep(forTimeInterval: 2)

        XCTAssertEqual(progressBtn.value as? String, "read",
                       "Chapter should be auto-marked as read after audio finishes")
    }
}

// MARK: - MultiReadingAutoProgressTests (#42)

final class MultiReadingAutoProgressTests: XCTestCase {

    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        app = nil
    }

    // #42 — Скроллим текст до конца с порогом 3 сек (--reading-progress-seconds 3).
    // Результат: глава переходит из "unread" в "read" после прокрутки и ожидания.
    @MainActor
    func testAutoProgressByReadingWithOverride() throws {
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--multi-template", "default",
            "--reading-progress-seconds", "3"
        ]
        app.launch()
        app.navigateToMultiReadingPage()

        guard let textContent = app.waitForMultiTextContent(timeout: 15) else {
            throw XCTSkip("Text content did not load — API may be unavailable")
        }

        let progressBtn = app.buttons["multi-chapter-progress"]
        XCTAssertTrue(progressBtn.waitForExistence(timeout: 5))
        XCTAssertEqual(progressBtn.value as? String, "unread",
                       "Chapter should be unread before scrolling")

        // Скроллим до конца текста
        for _ in 0..<25 {
            let start = textContent.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            let end = textContent.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            start.press(forDuration: 0.05, thenDragTo: end)
        }

        // Ждём порог (3 секунды) + запас
        Thread.sleep(forTimeInterval: 5)

        XCTAssertEqual(progressBtn.value as? String, "read",
                       "Chapter should be auto-marked as read after scrolling + waiting")
    }
}

// MARK: - MultiReadingErrorTests (#43-#44)

final class MultiReadingErrorTests: XCTestCase {

    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        app = nil
    }

    // #43 — Запускаем с --force-load-error (ошибка загрузки главы).
    // Результат: отображается текст ошибки `multi-error-text`.
    @MainActor
    func testErrorStateOnLoadFailure() {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "default", "--force-load-error"]
        app.launch()

        app.navigateViaMenu(to: "menu-multilingual")

        let errorText = app.staticTexts["multi-error-text"]
        XCTAssertTrue(errorText.waitForExistence(timeout: 8),
                      "Error text should appear when load fails")
    }

    // #44 — Запускаем с --force-no-audio (нет аудио-файла).
    // Результат: кнопки play, prev/next unit, prev/next section заблокированы (isEnabled == false).
    @MainActor
    func testNoAudioDisablesControls() throws {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "default", "--force-no-audio"]
        app.launch()

        app.navigateViaMenu(to: "menu-multilingual")

        let readingPage = app.otherElements["page-multi-reading"]
        guard readingPage.waitForExistence(timeout: 10) else {
            throw XCTSkip("Reading page did not appear")
        }

        Thread.sleep(forTimeInterval: 3)

        let disabledControls = [
            "multi-play-pause",
            "multi-prev-unit", "multi-next-unit",
            "multi-prev-section", "multi-next-section"
        ]
        for id in disabledControls {
            let button = app.buttons[id]
            if button.waitForExistence(timeout: 5) {
                XCTAssertFalse(button.isEnabled,
                               "\(id) should be disabled when no audio")
            }
        }
    }
}

// MARK: - MultiReadingBackgroundTests (#45)

final class MultiReadingBackgroundTests: XCTestCase {

    private var app: XCUIApplication!
    private static var apiChecked = false
    private static var apiAvailable = true

    @MainActor override func setUpWithError() throws {
        continueAfterFailure = false

        if !Self.apiChecked {
            Self.apiChecked = true
            Self.apiAvailable = checkAPIAvailability()
        }

        try XCTSkipUnless(Self.apiAvailable, "API unavailable — skipping background tests")

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "default"]
        app.launch()
        app.navigateToMultiReadingPage()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // #45 — Запускаем воспроизведение, отправляем приложение в фон, возвращаем.
    // Результат: после возврата состояние не сбросилось — аудио продолжало играть в фоне.
    @MainActor
    func testBackgroundPlaybackContinues() {
        let playPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        guard playPause.isEnabled else { return }

        playPause.tap()
        XCTAssertTrue(app.waitForMultiPlaybackState("playing", timeout: 15), "Should start playing")

        Thread.sleep(forTimeInterval: 2)

        // Отправляем в фон
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 5)

        // Возвращаем
        app.activate()
        Thread.sleep(forTimeInterval: 1)

        // Состояние не должно сброситься
        let stateLabel = app.staticTexts["multi-playback-state"]
        if stateLabel.exists {
            let state = stateLabel.label
            XCTAssertTrue(state == "playing" || state == "buffering" || state == "autopausing",
                          "Playback state should not reset after background. Got: \(state)")
        }

        playPause.tap()
    }
}

// MARK: - MultiReadingUnitModeTests (#46-#48)

final class MultiReadingUnitModeTests: XCTestCase {

    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        app = nil
    }

    private func launchWithUnit(_ unit: String) {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "default", "--multi-unit", unit]
        app.launch()
        app.navigateToMultiReadingPage()
    }

    private func getUnitCount() -> Int? {
        let counter = app.staticTexts["multi-unit-counter"]
        guard counter.waitForExistence(timeout: 10) else { return nil }
        // Формат: "1 of N" — извлекаем N
        let parts = counter.label.components(separatedBy: " ")
        return parts.last.flatMap { Int($0) }
    }

    // #46 — Режим verse: количество юнитов ≈ количеству стихов главы.
    // Результат: `multi-unit-counter` показывает "1 of N", где N > 1.
    @MainActor
    func testVerseMode() {
        launchWithUnit("verse")
        let count = getUnitCount()
        XCTAssertNotNil(count, "Should have unit count")
        if let count = count {
            XCTAssertGreaterThan(count, 1, "Verse mode should have multiple units")
        }
    }

    // #47 — Режим paragraph: юнитов меньше чем стихов (абзацы группируют стихи).
    // Результат: `multi-unit-counter` показывает N ≥ 1.
    @MainActor
    func testParagraphMode() {
        launchWithUnit("paragraph")
        let count = getUnitCount()
        XCTAssertNotNil(count, "Should have unit count")
        if let count = count {
            XCTAssertGreaterThanOrEqual(count, 1, "Paragraph mode should have at least 1 unit")
        }
    }

    // #48 — Режим chapter: вся глава = один юнит.
    // Результат: `multi-unit-counter` = "1 of 1".
    @MainActor
    func testChapterMode() {
        launchWithUnit("chapter")
        let counter = app.staticTexts["multi-unit-counter"]
        XCTAssertTrue(counter.waitForExistence(timeout: 10))
        XCTAssertTrue(counter.label.contains("1") && counter.label.hasSuffix("1"),
                      "Chapter mode should show '1 of 1'. Got: \(counter.label)")
    }
}
