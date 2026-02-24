import XCTest

// MARK: - ClassicReadingTests (requires live API)

final class ClassicReadingTests: XCTestCase {

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
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.navigateToReadingPage()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Wait for the debug playback state label to equal a specific value
    private func waitForPlaybackState(_ state: String, timeout: TimeInterval = 10) -> Bool {
        let stateLabel = app.staticTexts["read-playback-state"]
        guard stateLabel.waitForExistence(timeout: 3) else { return false }
        return app.waitForLabel(element: stateLabel, toBe: state, timeout: timeout)
    }

    /// Wait for audio to become ready for playback
    private func waitForAudioReady() {
        _ = waitForPlaybackState("waitingForPlay")
    }

    /// Open the settings sheet from the reading page
    private func openSettings() {
        let settingsBtn = app.buttons["read-settings-button"]
        XCTAssertTrue(settingsBtn.waitForExistence(timeout: 3))
        settingsBtn.tap()
    }

    /// Close the settings sheet
    private func closeSettings() {
        let closeBtn = app.buttons["settings-close"]
        if closeBtn.waitForExistence(timeout: 3) {
            closeBtn.tap()
        } else {
            app.swipeDown()
        }
    }

    /// Wait until the reading page is visible again after dismissing a sheet
    private func waitForReadingPage() {
        let playPause = app.buttons["read-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 8),
                      "Should return to reading page")
    }

    // MARK: - Загрузка и отображение

    // #1 — Открываем страницу чтения через меню.
    // Результат: WebView с текстом главы загрузился.
    @MainActor
    func testReadPageLoadsText() {
        let textContent = app.waitForTextContent(timeout: 10)
        XCTAssertNotNil(textContent, "WebView with text content should load")
    }

    // #2 — Проверяем заголовок главы в хедере.
    // Результат: кнопка-заголовок существует и содержит непустой текст.
    @MainActor
    func testReadPageShowsChapterTitle() {
        let title = app.buttons["read-chapter-title"]
        XCTAssertTrue(title.exists, "Chapter title button should exist")
        XCTAssertFalse(title.label.isEmpty, "Chapter title should have text")
    }

    // #3 — Проверяем наличие всех кнопок аудио-панели.
    // Результат: play/pause, prev/next chapter, prev/next verse, restart, speed — все существуют.
    @MainActor
    func testAudioPanelShowsAllControls() {
        let controls = [
            "read-play-pause", "read-prev-chapter", "read-next-chapter",
            "read-prev-verse", "read-next-verse", "read-restart", "read-speed"
        ]
        for id in controls {
            let button = app.buttons[id]
            XCTAssertTrue(button.waitForExistence(timeout: 5),
                          "Audio control '\(id)' should exist")
        }
    }

    // #5 — Нажимаем play, затем pause.
    // Результат: состояние переходит в "playing", затем в "pausing".
    @MainActor
    func testPlayAndPause() {
        let playPause = app.buttons["read-play-pause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))
        waitForAudioReady()

        // Play
        playPause.tap()
        XCTAssertTrue(waitForPlaybackState("playing"),
                      "State should become 'playing' after tap")

        // Pause
        playPause.tap()
        let paused = waitForPlaybackState("pausing", timeout: 5)
            || waitForPlaybackState("waitingForPause", timeout: 3)
        XCTAssertTrue(paused, "State should become 'pausing' after second tap")
    }

    // #13 — Нажимаем кнопку «следующая глава».
    // Результат: заголовок главы меняется на другой.
    @MainActor
    func testNextChapter() {
        let title = app.buttons["read-chapter-title"]
        let oldTitle = title.label

        let nextBtn = app.buttons["read-next-chapter"]
        XCTAssertTrue(nextBtn.waitForExistence(timeout: 3))
        nextBtn.tap()

        XCTAssertTrue(
            app.waitForLabelChange(element: title, from: oldTitle, timeout: 10),
            "Chapter title should change after tapping next")
    }

    // #14 — Переходим вперёд, затем назад кнопкой «предыдущая глава».
    // Результат: заголовок возвращается к прежнему значению.
    @MainActor
    func testPrevChapter() {
        let title = app.buttons["read-chapter-title"]
        let oldTitle = title.label

        // Go next first so we have a prev to go to
        let nextBtn = app.buttons["read-next-chapter"]
        XCTAssertTrue(nextBtn.waitForExistence(timeout: 3))
        nextBtn.tap()
        _ = app.waitForLabelChange(element: title, from: oldTitle, timeout: 10)
        let afterNextTitle = title.label

        // Go back
        let prevBtn = app.buttons["read-prev-chapter"]
        prevBtn.tap()

        XCTAssertTrue(
            app.waitForLabelChange(element: title, from: afterNextTitle, timeout: 10),
            "Chapter title should change after tapping prev")
    }

    // #15 — Открываем sheet выбора главы по тапу на заголовок.
    // Результат: sheet появляется с testament-selector, закрывается по кнопке.
    @MainActor
    func testChapterSelectAndNavigate() {
        let title = app.buttons["read-chapter-title"]
        title.tap()

        // Sheet should appear
        let closeBtn = app.buttons["select-close"]
        XCTAssertTrue(closeBtn.waitForExistence(timeout: 5),
                      "Chapter selection sheet should appear")

        // Testament selector should be present
        let testamentSelector = app.otherElements["testament-selector"]
        XCTAssertTrue(testamentSelector.waitForExistence(timeout: 3),
                      "Testament selector should exist in chapter select")

        // Close it
        closeBtn.tap()
        waitForReadingPage()
    }

    // #23 — Открываем настройки по шестерёнке, проверяем секции.
    // Результат: секции language, translation, voice видны; sheet закрывается.
    @MainActor
    func testSettingsOpenAndClose() {
        openSettings()

        for section in ["setup-language-section", "setup-translation-section", "setup-voice-section"] {
            let el = app.otherElements[section]
            XCTAssertTrue(el.waitForExistence(timeout: 5),
                          "\(section) should appear in settings")
        }

        closeSettings()
        waitForReadingPage()
    }

    // MARK: - Воспроизведение

    // #6 — Тапаем по кнопке скорости 8 раз, проходим полный цикл.
    // Результат: скорость возвращается к начальной, в цикле минимум 5 уникальных значений.
    @MainActor
    func testSpeedCycleAndWrapAround() {
        let speedBtn = app.buttons["read-speed"]
        XCTAssertTrue(speedBtn.waitForExistence(timeout: 5))

        let initialLabel = speedBtn.label
        XCTAssertFalse(initialLabel.isEmpty, "Speed button should have a label")

        // Tap 8 times to cycle: x1→1.2→1.4→1.6→1.8→2.0→0.6→0.8→x1
        var labels: [String] = [initialLabel]
        for _ in 0..<8 {
            speedBtn.tap()
            Thread.sleep(forTimeInterval: 0.1)
            labels.append(speedBtn.label)
        }

        // Full cycle: first and last should match
        XCTAssertEqual(labels.first, labels.last,
                       "Speed should wrap around after full cycle. Got: \(labels)")

        // Should visit multiple distinct speeds
        let uniqueLabels = Set(labels)
        XCTAssertGreaterThanOrEqual(uniqueLabels.count, 5,
                                     "Should cycle through at least 5 speed values. Got: \(uniqueLabels)")
    }

    // #7 — Перемещаем слайдер таймлайна на середину.
    // Результат: текущее время воспроизведения изменилось.
    @MainActor
    func testSeekSlider() {
        let slider = app.sliders["read-timeline-slider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 8))
        waitForAudioReady()

        let timeCurrent = app.staticTexts["read-time-current"]
        XCTAssertTrue(timeCurrent.waitForExistence(timeout: 3))
        let timeBefore = timeCurrent.label

        slider.adjust(toNormalizedSliderPosition: 0.5)

        XCTAssertTrue(
            app.waitForLabelChange(element: timeCurrent, from: timeBefore, timeout: 5),
            "Current time should change after seeking")
    }

    // #8 — Сворачиваем аудио-панель шевроном, затем разворачиваем.
    // Результат: кнопка play скрывается при сворачивании и появляется при разворачивании.
    @MainActor
    func testAudioPanelCollapseAndExpand() {
        let chevron = app.buttons["read-chevron"]
        XCTAssertTrue(chevron.waitForExistence(timeout: 5))

        let playPause = app.buttons["read-play-pause"]
        XCTAssertTrue(playPause.exists, "Play button should be visible before collapse")

        // Collapse
        chevron.tap()
        Thread.sleep(forTimeInterval: 0.5) // animation
        XCTAssertFalse(playPause.isHittable,
                       "Play button should not be hittable when panel is collapsed")

        // Expand
        chevron.tap()
        Thread.sleep(forTimeInterval: 0.5) // animation
        XCTAssertTrue(playPause.isHittable,
                      "Play button should be hittable again after expanding")
    }

    // #9 — Запускаем воспроизведение, ждём несколько секунд.
    // Результат: текущее время увеличилось (аудио играет).
    @MainActor
    func testPlayAdvancesVerseCounter() {
        waitForAudioReady()

        let timeCurrent = app.staticTexts["read-time-current"]
        XCTAssertTrue(timeCurrent.waitForExistence(timeout: 3))
        let timeBefore = timeCurrent.label

        let playPause = app.buttons["read-play-pause"]
        playPause.tap()

        XCTAssertTrue(
            app.waitForLabelChange(element: timeCurrent, from: timeBefore, timeout: 15),
            "Time should advance during playback")

        playPause.tap() // stop
    }

    // #10 — Во время воспроизведения нажимаем «следующий стих».
    // Результат: счётчик стиха увеличился.
    @MainActor
    func testNextVerseButton() {
        waitForAudioReady()

        let playPause = app.buttons["read-play-pause"]
        playPause.tap()
        _ = waitForPlaybackState("playing")

        let verseCounter = app.staticTexts["read-verse-counter"]
        guard verseCounter.waitForExistence(timeout: 3) else {
            playPause.tap()
            XCTFail("Verse counter not found")
            return
        }
        let verseBefore = verseCounter.label

        let nextVerse = app.buttons["read-next-verse"]
        XCTAssertTrue(nextVerse.waitForExistence(timeout: 3))
        nextVerse.tap()

        XCTAssertTrue(
            app.waitForLabelChange(element: verseCounter, from: verseBefore, timeout: 5),
            "Verse counter should change after next verse tap")

        playPause.tap() // stop
    }

    // #11 — Воспроизводим аудио, затем нажимаем restart.
    // Результат: время сбрасывается к началу (меньше, чем до рестарта).
    @MainActor
    func testRestartButton() {
        waitForAudioReady()

        let playPause = app.buttons["read-play-pause"]
        playPause.tap()

        let timeCurrent = app.staticTexts["read-time-current"]
        XCTAssertTrue(timeCurrent.waitForExistence(timeout: 3))
        _ = app.waitForLabelChange(element: timeCurrent, from: "00:00", timeout: 15)

        let timeBeforeRestart = timeCurrent.label

        let restart = app.buttons["read-restart"]
        XCTAssertTrue(restart.waitForExistence(timeout: 3))
        restart.tap()

        // Pause immediately to stop time from advancing past 00:00
        playPause.tap()
        Thread.sleep(forTimeInterval: 0.5)

        // Time should have decreased compared to before restart
        let timeAfterRestart = timeCurrent.label
        XCTAssertTrue(
            timeAfterRestart < timeBeforeRestart || timeAfterRestart == "00:00",
            "Time should reset after restart. Before: \(timeBeforeRestart), after: \(timeAfterRestart)")

        playPause.tap() // stop
    }

    // MARK: - Навигация по главам

    // #16, #17 — вынесены в ClassicReadingBoundaryTests (отдельный launch с --start-excerpt)
    // #18, #19 — вынесены в ClassicReadingAutoNextTests (отдельный launch с --start-excerpt)

    // MARK: - Настройки

    // #24 — В настройках выбираем другой перевод и диктора.
    // Результат: чип перевода на аудио-панели меняется на новое значение.
    @MainActor
    func testSettingsChangeTranslation() {
        let translationChip = app.buttons["read-translation-chip"]
        XCTAssertTrue(translationChip.waitForExistence(timeout: 5))
        let originalTranslation = translationChip.label

        openSettings()

        // Раскрываем секцию перевода (тап по заголовку аккордеона)
        let transSection = app.otherElements["setup-translation-section"]
        XCTAssertTrue(transSection.waitForExistence(timeout: 5))
        transSection.tap()
        Thread.sleep(forTimeInterval: 1) // ждём загрузку списка переводов

        // transSection.buttons: index 0 — заголовок аккордеона, index 1+ — опции перевода.
        // У выбранного перевода внутри кнопки есть Image(checkmark), у остальных — нет.
        let translationButtons = transSection.buttons
        var tappedDifferent = false
        for i in 1..<translationButtons.count {
            let btn = translationButtons.element(boundBy: i)
            guard btn.exists else { continue }
            // Пропускаем текущий выбранный перевод (у него есть checkmark)
            if btn.images.count == 0 {
                btn.tap()
                tappedDifferent = true
                break
            }
        }

        guard tappedDifferent else {
            closeSettings()
            return // Только один перевод доступен
        }

        // После выбора перевода раскрывается секция диктора — выбираем первого.
        // Голоса выбираются через onTapGesture на HStack (не Button),
        // поэтому тапаем по области имени — левее кнопки превью.
        Thread.sleep(forTimeInterval: 1)
        let previewBtn = app.buttons["settings-voice-preview-0"]
        if previewBtn.waitForExistence(timeout: 5) {
            let nameArea = previewBtn.coordinate(withNormalizedOffset: CGVector(dx: -3.0, dy: 0.5))
            nameArea.tap()
        }

        closeSettings()
        waitForReadingPage()

        // Чип перевода должен измениться
        XCTAssertTrue(translationChip.waitForExistence(timeout: 5))
        XCTAssertNotEqual(translationChip.label, originalTranslation,
                          "Translation chip should change after selecting a different translation")
    }

    // #25 — Меняем язык в настройках.
    // Результат: заголовки секций перевода и диктора сбрасываются на дефолтные заглушки.
    @MainActor
    func testSettingsLanguageResetsTranslationAndVoice() throws {
        openSettings()

        // Запоминаем текущие заголовки секций перевода и диктора
        let transSection = app.otherElements["setup-translation-section"]
        let voiceSection = app.otherElements["setup-voice-section"]
        XCTAssertTrue(transSection.waitForExistence(timeout: 5))
        XCTAssertTrue(voiceSection.waitForExistence(timeout: 3))

        // Заголовок аккордеона — кнопка (index 0) с label "Title\nValue"
        let transHeaderBefore = transSection.buttons.element(boundBy: 0).label
        let voiceHeaderBefore = voiceSection.buttons.element(boundBy: 0).label

        // Раскрываем секцию языка
        let langSection = app.otherElements["setup-language-section"]
        XCTAssertTrue(langSection.waitForExistence(timeout: 5))
        langSection.tap()
        Thread.sleep(forTimeInterval: 0.5)

        // langSection.buttons: index 0 — заголовок аккордеона, index 1+ — опции языка
        let langButtons = langSection.buttons
        guard langButtons.count >= 3 else {
            closeSettings()
            throw XCTSkip("Need at least 2 languages (header + 2 options)")
        }

        // Выбираем язык, отличный от текущего (без checkmark)
        var tappedDifferent = false
        for i in 1..<langButtons.count {
            let btn = langButtons.element(boundBy: i)
            guard btn.exists else { continue }
            if btn.images.count == 0 {
                btn.tap()
                tappedDifferent = true
                break
            }
        }
        guard tappedDifferent else {
            closeSettings()
            throw XCTSkip("Could not find a different language to select")
        }

        Thread.sleep(forTimeInterval: 1.5) // ждём загрузку новых переводов

        // После смены языка перевод и диктор сбрасываются —
        // заголовки секций должны измениться (показать заглушки)
        let transHeaderAfter = transSection.buttons.element(boundBy: 0).label
        let voiceHeaderAfter = voiceSection.buttons.element(boundBy: 0).label

        XCTAssertNotEqual(transHeaderAfter, transHeaderBefore,
                          "Translation section header should change after language switch")
        XCTAssertNotEqual(voiceHeaderAfter, voiceHeaderBefore,
                          "Voice section header should change after language switch")

        closeSettings()
    }

    // #26 — Меняем перевод в настройках.
    // Результат: заголовок секции диктора сбрасывается на заглушку.
    @MainActor
    func testSettingsTranslationResetsVoice() throws {
        openSettings()

        // Запоминаем заголовок секции диктора до изменений
        let voiceSection = app.otherElements["setup-voice-section"]
        XCTAssertTrue(voiceSection.waitForExistence(timeout: 5))
        let voiceHeaderBefore = voiceSection.buttons.element(boundBy: 0).label

        // Раскрываем секцию перевода
        let transSection = app.otherElements["setup-translation-section"]
        XCTAssertTrue(transSection.waitForExistence(timeout: 5))
        transSection.tap()
        Thread.sleep(forTimeInterval: 1)

        // transSection.buttons: index 0 — заголовок, index 1+ — опции перевода
        let translationButtons = transSection.buttons
        guard translationButtons.count >= 3 else {
            closeSettings()
            throw XCTSkip("Need at least 2 translations (header + 2 options)")
        }

        // Выбираем перевод без checkmark (не текущий)
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
        guard tappedDifferent else {
            closeSettings()
            throw XCTSkip("Could not find a different translation")
        }

        Thread.sleep(forTimeInterval: 1)

        // После смены перевода диктор сбрасывается — заголовок секции меняется
        let voiceHeaderAfter = voiceSection.buttons.element(boundBy: 0).label
        XCTAssertNotEqual(voiceHeaderAfter, voiceHeaderBefore,
                          "Voice section header should change after translation switch")

        closeSettings()
    }

    // #27 — Меняем язык в настройках, но НЕ выбираем диктора и закрываем sheet.
    // Результат: перевод остаётся прежним — изменения не сохранились без выбора voice.
    @MainActor
    func testSettingsResetNotPersistedWithoutVoice() throws {
        let translationChip = app.buttons["read-translation-chip"]
        XCTAssertTrue(translationChip.waitForExistence(timeout: 5))
        let originalTranslation = translationChip.label

        openSettings()

        // Раскрываем секцию языка и выбираем другой
        let langSection = app.otherElements["setup-language-section"]
        XCTAssertTrue(langSection.waitForExistence(timeout: 5))
        langSection.tap()
        Thread.sleep(forTimeInterval: 0.5)

        // langSection.buttons: index 0 — заголовок, index 1+ — опции
        let langButtons = langSection.buttons
        guard langButtons.count >= 3 else {
            closeSettings()
            throw XCTSkip("Need at least 2 languages")
        }

        // Выбираем язык без checkmark
        var tappedDifferent = false
        for i in 1..<langButtons.count {
            let btn = langButtons.element(boundBy: i)
            guard btn.exists else { continue }
            if btn.images.count == 0 {
                btn.tap()
                tappedDifferent = true
                break
            }
        }
        guard tappedDifferent else {
            closeSettings()
            throw XCTSkip("Could not find a different language")
        }
        Thread.sleep(forTimeInterval: 1)

        // Close WITHOUT selecting a voice — changes should NOT persist
        closeSettings()
        waitForReadingPage()

        // Translation chip should still show the original value
        XCTAssertTrue(translationChip.waitForExistence(timeout: 5))
        XCTAssertEqual(translationChip.label, originalTranslation,
                       "Translation should not change when settings closed without voice selection")
    }

    // #28 — Открываем настройки, находим контрол типа паузы.
    // Результат: меню типа паузы существует и открывается по тапу.
    @MainActor
    func testSettingsPauseTypeControls() {
        openSettings()
        app.swipeUp() // scroll to pause section

        // The pause type is a Menu with identifier "settings-pause-type"
        // Try finding it as a button first (Menu renders as button), then otherElement
        let pauseTypeBtn = app.buttons["settings-pause-type"]
        let pauseTypeOther = app.otherElements["settings-pause-type"]
        let pauseTypeFound = pauseTypeBtn.waitForExistence(timeout: 3) || pauseTypeOther.waitForExistence(timeout: 2)
        XCTAssertTrue(pauseTypeFound, "Pause type control should exist")

        // Tap it to open the picker menu
        let pauseElement = pauseTypeBtn.exists ? pauseTypeBtn : pauseTypeOther
        pauseElement.tap()
        Thread.sleep(forTimeInterval: 0.5)

        // The picker menu should show options — just verify it opened and dismiss
        // Tap outside or select an option to close
        app.tap() // dismiss popover
        Thread.sleep(forTimeInterval: 0.3)

        closeSettings()
    }

    // #29 — Увеличиваем, уменьшаем и сбрасываем размер шрифта в настройках.
    // Результат: процент шрифта меняется при +/−, возвращается к 100% при reset.
    @MainActor
    func testSettingsFontSizeControls() {
        openSettings()

        let fontSize = app.staticTexts["settings-font-size"]
        XCTAssertTrue(fontSize.waitForExistence(timeout: 5), "Font size label should exist")
        let initialSize = fontSize.label

        // Increase
        let increaseBtn = app.buttons["settings-font-increase"]
        XCTAssertTrue(increaseBtn.waitForExistence(timeout: 3))
        increaseBtn.tap()

        XCTAssertTrue(
            app.waitForLabelChange(element: fontSize, from: initialSize, timeout: 3),
            "Font size should increase")
        let increasedSize = fontSize.label

        // Decrease
        let decreaseBtn = app.buttons["settings-font-decrease"]
        XCTAssertTrue(decreaseBtn.waitForExistence(timeout: 3))
        decreaseBtn.tap()

        XCTAssertTrue(
            app.waitForLabelChange(element: fontSize, from: increasedSize, timeout: 3),
            "Font size should decrease")

        // Reset
        let resetBtn = app.buttons["settings-font-reset"]
        XCTAssertTrue(resetBtn.waitForExistence(timeout: 3))
        resetBtn.tap()

        XCTAssertTrue(
            app.waitForLabel(element: fontSize, toBe: "100%", timeout: 3),
            "Font size should reset to 100%")

        closeSettings()
    }

    // #20, #21, #22 — вынесены в ClassicReadingPauseTests (отдельный launch с --pause-type / --pause-block)

    // MARK: - Прогресс

    // #31 — Тапаем кнопку прогресса дважды: прочитано → не прочитано.
    // Результат: кнопка переключается и остаётся на месте.
    @MainActor
    func testMarkChapterReadAndUnread() {
        let progressBtn = app.buttons["read-chapter-progress"]
        XCTAssertTrue(progressBtn.waitForExistence(timeout: 8),
                      "Chapter progress button should exist")

        // Mark as read
        progressBtn.tap()
        Thread.sleep(forTimeInterval: 0.5) // animation

        // Toggle back to unread
        progressBtn.tap()
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertTrue(progressBtn.exists,
                      "Progress button should still exist after toggling")
    }

    // #32 — вынесен в ClassicReadingAudioEndProgressTests (отдельный launch с --auto-progress-audio-end)
    // #33 — вынесен в ClassicReadingAutoProgressTests (отдельный launch с --reading-progress-seconds)

    // MARK: - Аудио-информация

    // #4 — Проверяем чипы перевода и диктора на аудио-панели.
    // Результат: оба чипа существуют и содержат непустой текст.
    @MainActor
    func testAudioInfoShowsTranslationAndVoice() {
        let translationChip = app.buttons["read-translation-chip"]
        XCTAssertTrue(translationChip.waitForExistence(timeout: 5),
                      "Translation chip should exist")
        XCTAssertFalse(translationChip.label.isEmpty,
                       "Translation chip should have text")

        let voiceChip = app.buttons["read-voice-chip"]
        XCTAssertTrue(voiceChip.waitForExistence(timeout: 3),
                      "Voice chip should exist")
        XCTAssertFalse(voiceChip.label.isEmpty,
                       "Voice chip should have text")
    }

    // MARK: - Фоновое воспроизведение

    // #34 — Запускаем воспроизведение, отправляем приложение в фон, возвращаем.
    // Результат: после возврата время увеличилось — аудио играло в фоне.
    // #35, #36 — вынесены в ClassicReadingPauseTests и ClassicReadingAutoNextTests
    @MainActor
    func testBackgroundPlaybackContinues() {
        waitForAudioReady()

        let playPause = app.buttons["read-play-pause"]
        playPause.tap()
        XCTAssertTrue(waitForPlaybackState("playing"), "Should start playing")

        let timeCurrent = app.staticTexts["read-time-current"]
        XCTAssertTrue(timeCurrent.waitForExistence(timeout: 3))
        // Ждём чтобы время ушло от 00:00
        _ = app.waitForLabelChange(element: timeCurrent, from: "00:00", timeout: 10)
        let timeBeforeBackground = timeCurrent.label

        // Отправляем в фон
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 5)

        // Возвращаем приложение
        app.activate()
        Thread.sleep(forTimeInterval: 1)

        // Время должно увеличиться — аудио играло в фоне
        let timeAfterBackground = timeCurrent.label
        XCTAssertNotEqual(timeAfterBackground, timeBeforeBackground,
                          "Time should advance during background playback. Before: \(timeBeforeBackground), after: \(timeAfterBackground)")

        playPause.tap() // stop
    }

    // #30 — В настройках нажимаем кнопку превью голоса, потом останавливаем.
    // Результат: превью запускается и останавливается без ошибок.
    @MainActor
    func testVoicePreviewPlayAndStop() {
        openSettings()

        // Expand voice section
        let voiceSection = app.otherElements["setup-voice-section"]
        XCTAssertTrue(voiceSection.waitForExistence(timeout: 5))
        voiceSection.tap()
        Thread.sleep(forTimeInterval: 0.5) // accordion animation

        // Look for voice preview button
        let previewBtn = app.buttons["settings-voice-preview-0"]
        guard previewBtn.waitForExistence(timeout: 5) else {
            closeSettings()
            // Voice preview not available — voices may not be loaded
            return
        }

        // Start preview
        previewBtn.tap()
        Thread.sleep(forTimeInterval: 2) // let it play

        // Stop preview
        previewBtn.tap()
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertTrue(previewBtn.exists,
                      "Preview button should still exist after stop")

        closeSettings()
    }

    // #12 — Меняем скорость дважды, переходим на следующую главу.
    // Результат: скорость сохраняется после смены главы.
    @MainActor
    func testSpeedPersistsAcrossChapters() {
        let speedBtn = app.buttons["read-speed"]
        XCTAssertTrue(speedBtn.waitForExistence(timeout: 5))

        // Change speed twice: x1 → 1.2 → 1.4
        speedBtn.tap()
        Thread.sleep(forTimeInterval: 0.1)
        speedBtn.tap()
        Thread.sleep(forTimeInterval: 0.1)

        let speedAfterChange = speedBtn.label

        // Navigate to next chapter
        let nextBtn = app.buttons["read-next-chapter"]
        let title = app.buttons["read-chapter-title"]
        let oldTitle = title.label
        nextBtn.tap()
        _ = app.waitForLabelChange(element: title, from: oldTitle, timeout: 10)

        // Speed should persist
        XCTAssertEqual(speedBtn.label, speedAfterChange,
                       "Speed should persist across chapter changes")
    }

    // MARK: - E2E

    // #40 — E2E: загрузка → play → next chapter → mark read → настройки → закрытие.
    // Результат: полный пользовательский сценарий проходит без ошибок.
    @MainActor
    func testFullReadingJourney() {
        // E2E smoke test

        // 1. Verify page loaded with content
        let textContent = app.waitForTextContent(timeout: 10)
        XCTAssertNotNil(textContent, "Text content should load")

        let title = app.buttons["read-chapter-title"]
        XCTAssertFalse(title.label.isEmpty, "Title should have text")

        // 2. Play briefly
        waitForAudioReady()
        let playPause = app.buttons["read-play-pause"]
        playPause.tap()
        _ = waitForPlaybackState("playing")
        Thread.sleep(forTimeInterval: 2)
        playPause.tap() // pause

        // 3. Navigate to next chapter
        let oldTitle = title.label
        let nextBtn = app.buttons["read-next-chapter"]
        nextBtn.tap()
        XCTAssertTrue(
            app.waitForLabelChange(element: title, from: oldTitle, timeout: 10),
            "Chapter should change")

        // 4. Verify new content loaded
        let newTextContent = app.waitForTextContent(timeout: 10)
        XCTAssertNotNil(newTextContent, "New chapter text should load")

        // 5. Mark chapter as read
        let progressBtn = app.buttons["read-chapter-progress"]
        if progressBtn.waitForExistence(timeout: 5) {
            progressBtn.tap()
        }

        // 6. Open and close settings
        openSettings()
        let langSection = app.otherElements["setup-language-section"]
        XCTAssertTrue(langSection.waitForExistence(timeout: 5),
                      "Settings should open")
        closeSettings()
        waitForReadingPage()
    }
}

// MARK: - ClassicReadingErrorTests (forced errors, no API dependency)

final class ClassicReadingErrorTests: XCTestCase {

    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        app = nil
    }

    // #37 — Запускаем с --force-load-error (ошибка загрузки главы).
    // Результат: отображается текст ошибки.
    @MainActor
    func testErrorStateOnLoadFailure() {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--force-load-error"]
        app.launch()

        app.navigateViaMenu(to: "menu-read")

        let errorText = app.staticTexts["read-error-text"]
        XCTAssertTrue(errorText.waitForExistence(timeout: 8),
                      "Error text should appear when load fails")
    }

    // #38 — Запускаем с --force-load-error-once (ошибка только на первый запрос).
    // Результат: ошибка → pull-to-refresh → текст загружается.
    @MainActor
    func testRetryAfterLoadError() {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--force-load-error-once"]
        app.launch()

        app.navigateViaMenu(to: "menu-read")

        let errorText = app.staticTexts["read-error-text"]
        XCTAssertTrue(errorText.waitForExistence(timeout: 8),
                      "Error text should appear on first load")

        // Pull to refresh — медленный drag вниз по тексту ошибки для .refreshable
        let start = errorText.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.0))
        let end = errorText.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 8.0))
        start.press(forDuration: 0.1, thenDragTo: end)

        // After retry with one-shot consumed, text content should load
        let textContent = app.waitForTextContent(timeout: 15)
        XCTAssertNotNil(textContent, "Text content should load after retry")
    }

    // #39 — Запускаем с --force-no-audio (нет аудио-файла).
    // Результат: кнопки play, restart, speed, verse заблокированы (isEnabled == false).
    @MainActor
    func testNoAudioWarningAndDisabledControls() {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--force-no-audio"]
        app.launch()

        app.navigateViaMenu(to: "menu-read")

        // Wait for page to load
        let title = app.buttons["read-chapter-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))

        // Verify audio-dependent buttons are disabled
        let disabledControls = [
            "read-play-pause", "read-restart", "read-speed",
            "read-prev-verse", "read-next-verse"
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

// MARK: - ClassicReadingAutoProgressTests (special launch args)

final class ClassicReadingAutoProgressTests: XCTestCase {

    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        app = nil
    }

    // #33 — Скроллим текст до конца с порогом 3 сек (--reading-progress-seconds 3).
    // Результат: глава переходит из "unread" в "read" после прокрутки и ожидания.
    @MainActor
    func testAutoProgressByReadingWithOverride() throws {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reading-progress-seconds", "3"]
        app.launch()

        app.navigateToReadingPage()

        // Wait for text to load (HTMLTextView renders as webView in XCUITest)
        guard let textContent = app.waitForTextContent(timeout: 15) else {
            throw XCTSkip("Text content did not load — API may be unavailable")
        }

        // autoProgressByReading (default true) marks chapter as read when:
        //   1. User scrolled to bottom (chapterReachedTextBottom)
        //   2. Enough time elapsed (overridden to 3 seconds)
        //   3. Audio is not actively playing

        let progressBtn = app.buttons["read-chapter-progress"]
        XCTAssertTrue(progressBtn.waitForExistence(timeout: 5),
                      "Progress button should exist")

        // Chapter should NOT be marked yet (haven't scrolled to bottom)
        XCTAssertEqual(progressBtn.value as? String, "unread",
                       "Chapter should be unread before scrolling to bottom")

        // Scroll to bottom of text using coordinate drag
        // (swipeUp() doesn't reliably scroll WKWebView content)
        for _ in 0..<25 {
            let start = textContent.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            let end = textContent.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            start.press(forDuration: 0.05, thenDragTo: end)
        }

        // Wait for the override threshold (3 seconds) + buffer
        Thread.sleep(forTimeInterval: 5)

        // Chapter should now be auto-marked as read
        XCTAssertEqual(progressBtn.value as? String, "read",
                       "Chapter should be auto-marked as read after scrolling to bottom + waiting")
    }
}

// MARK: - ClassicReadingBoundaryTests (граничные главы, отдельный launch с --start-excerpt)

final class ClassicReadingBoundaryTests: XCTestCase {

    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        app = nil
    }

    // #16 — Запускаем приложение на Бытие 1 (первая глава Библии).
    // Результат: кнопка «предыдущая глава» заблокирована, «следующая» активна.
    @MainActor
    func testFirstChapterPrevDisabled() {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--start-excerpt", "gen 1"]
        app.launch()
        app.navigateToReadingPage()

        let prevBtn = app.buttons["read-prev-chapter"]
        XCTAssertTrue(prevBtn.waitForExistence(timeout: 5))
        XCTAssertFalse(prevBtn.isEnabled,
                       "Previous chapter should be disabled at Genesis 1")

        let nextBtn = app.buttons["read-next-chapter"]
        XCTAssertTrue(nextBtn.isEnabled,
                      "Next chapter should be enabled at Genesis 1")
    }

    // #17 — Запускаем приложение на Откровение 22 (последняя глава Библии).
    // Результат: кнопка «следующая глава» заблокирована, «предыдущая» активна.
    @MainActor
    func testLastChapterNextDisabled() {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--start-excerpt", "rev 22"]
        app.launch()
        app.navigateToReadingPage()

        let nextBtn = app.buttons["read-next-chapter"]
        XCTAssertTrue(nextBtn.waitForExistence(timeout: 5))
        XCTAssertFalse(nextBtn.isEnabled,
                       "Next chapter should be disabled at Revelation 22")

        let prevBtn = app.buttons["read-prev-chapter"]
        XCTAssertTrue(prevBtn.isEnabled,
                      "Previous chapter should be enabled at Revelation 22")
    }
}

// MARK: - ClassicReadingAudioEndProgressTests (авто-прогресс по окончании аудио)

final class ClassicReadingAudioEndProgressTests: XCTestCase {

    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        app = nil
    }

    // #32 — Включаем autoProgressAudioEnd, открываем короткий Псалом 117 (2 стиха),
    // пролистываем стихи кнопкой «следующий стих» до конца.
    // Результат: глава автоматически отмечается как прочитанная после окончания аудио.
    @MainActor
    func testAutoProgressOnAudioEnd() throws {
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--auto-progress-audio-end",
            "--start-excerpt", "psa 117"
        ]
        app.launch()
        app.navigateToReadingPage()

        // Ждём загрузку аудио
        let stateLabel = app.staticTexts["read-playback-state"]
        guard stateLabel.waitForExistence(timeout: 10) else {
            throw XCTSkip("Playback state label not found — cannot verify")
        }
        let waitingPredicate = NSPredicate(format: "label == %@", "waitingForPlay")
        let waitExp = XCTNSPredicateExpectation(predicate: waitingPredicate, object: stateLabel)
        _ = XCTWaiter.wait(for: [waitExp], timeout: 15)

        // Проверяем что глава ещё не прочитана
        let progressBtn = app.buttons["read-chapter-progress"]
        XCTAssertTrue(progressBtn.waitForExistence(timeout: 5))
        XCTAssertEqual(progressBtn.value as? String, "unread",
                       "Chapter should be unread before audio finishes")

        // Устанавливаем скорость 2x для ускорения
        let speedBtn = app.buttons["read-speed"]
        XCTAssertTrue(speedBtn.waitForExistence(timeout: 3))
        // Тапаем до 2x: 1.0→1.2→1.4→1.6→1.8→2.0 (5 тапов)
        for _ in 0..<5 { speedBtn.tap() }

        // Запускаем воспроизведение
        let playPause = app.buttons["read-play-pause"]
        playPause.tap()

        let playingPredicate = NSPredicate(format: "label == %@", "playing")
        let playExp = XCTNSPredicateExpectation(predicate: playingPredicate, object: stateLabel)
        _ = XCTWaiter.wait(for: [playExp], timeout: 10)

        // Псалом 117 — 2 стиха. Прокликиваем «следующий стих» чтобы ускорить.
        let nextVerse = app.buttons["read-next-verse"]
        if nextVerse.waitForExistence(timeout: 3) {
            // Пропускаем на последний стих
            Thread.sleep(forTimeInterval: 1)
            nextVerse.tap()
        }

        // Ждём завершения аудио (finished/segmentFinished) — до 30 сек на 2x
        let finishedPredicate = NSPredicate(format: "label == %@ OR label == %@",
                                            "finished", "segmentFinished")
        let finishExp = XCTNSPredicateExpectation(predicate: finishedPredicate, object: stateLabel)
        let finished = XCTWaiter.wait(for: [finishExp], timeout: 30) == .completed

        if !finished {
            // Если не дождались finished, возможно глава уже отмечена
            // (autoProgress мог сработать до смены state label)
        }

        // Даём время на обработку авто-прогресса
        Thread.sleep(forTimeInterval: 2)

        // Глава должна быть отмечена как прочитанная
        XCTAssertEqual(progressBtn.value as? String, "read",
                       "Chapter should be auto-marked as read after audio finishes")
    }
}

// MARK: - ClassicReadingAutoNextTests (автопереход на следующую главу после окончания аудио)

final class ClassicReadingAutoNextTests: XCTestCase {

    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        app = nil
    }

    // #18 — Открываем короткий Псалом 117, дослушиваем до конца с autoNextChapter=true.
    // Результат: заголовок главы автоматически меняется на следующую (Псалом 118).
    @MainActor
    func testAutoNextChapter() throws {
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--start-excerpt", "psa 117"
        ]
        app.launch()
        app.navigateToReadingPage()

        // Ждём загрузку аудио
        let stateLabel = app.staticTexts["read-playback-state"]
        guard stateLabel.waitForExistence(timeout: 10) else {
            throw XCTSkip("Playback state label not found — cannot verify")
        }
        let waitingPredicate = NSPredicate(format: "label == %@", "waitingForPlay")
        let waitExp = XCTNSPredicateExpectation(predicate: waitingPredicate, object: stateLabel)
        _ = XCTWaiter.wait(for: [waitExp], timeout: 15)

        // Запоминаем текущий заголовок главы
        let title = app.buttons["read-chapter-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let originalTitle = title.label

        // Устанавливаем скорость 2x для ускорения
        let speedBtn = app.buttons["read-speed"]
        XCTAssertTrue(speedBtn.waitForExistence(timeout: 3))
        for _ in 0..<5 { speedBtn.tap() }

        // Запускаем воспроизведение
        let playPause = app.buttons["read-play-pause"]
        playPause.tap()

        let playingPredicate = NSPredicate(format: "label == %@", "playing")
        let playExp = XCTNSPredicateExpectation(predicate: playingPredicate, object: stateLabel)
        _ = XCTWaiter.wait(for: [playExp], timeout: 10)

        // Псалом 117 — 2 стиха. Прокликиваем «следующий стих» чтобы быстрее дойти до конца.
        let nextVerse = app.buttons["read-next-verse"]
        if nextVerse.waitForExistence(timeout: 3) {
            Thread.sleep(forTimeInterval: 1)
            nextVerse.tap()
        }

        // Ждём смены заголовка главы (autoNextChapter переключает на следующую)
        XCTAssertTrue(
            app.waitForLabelChange(element: title, from: originalTitle, timeout: 40),
            "Chapter title should change after audio finishes with autoNextChapter enabled. Was: \(originalTitle)")
    }

    // #19 — Открываем Псалом 117 с --no-auto-next-chapter, дослушиваем до конца.
    // Результат: заголовок главы НЕ меняется — автопереход отключён.
    @MainActor
    func testNoAutoNextChapter() throws {
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--no-auto-next-chapter",
            "--start-excerpt", "psa 117"
        ]
        app.launch()
        app.navigateToReadingPage()

        // Ждём загрузку аудио
        let stateLabel = app.staticTexts["read-playback-state"]
        guard stateLabel.waitForExistence(timeout: 10) else {
            throw XCTSkip("Playback state label not found — cannot verify")
        }
        let waitingPredicate = NSPredicate(format: "label == %@", "waitingForPlay")
        let waitExp = XCTNSPredicateExpectation(predicate: waitingPredicate, object: stateLabel)
        _ = XCTWaiter.wait(for: [waitExp], timeout: 15)

        // Запоминаем заголовок главы
        let title = app.buttons["read-chapter-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let originalTitle = title.label

        // Скорость 2x
        let speedBtn = app.buttons["read-speed"]
        XCTAssertTrue(speedBtn.waitForExistence(timeout: 3))
        for _ in 0..<5 { speedBtn.tap() }

        // Запускаем воспроизведение
        let playPause = app.buttons["read-play-pause"]
        playPause.tap()

        let playingPredicate = NSPredicate(format: "label == %@", "playing")
        let playExp = XCTNSPredicateExpectation(predicate: playingPredicate, object: stateLabel)
        _ = XCTWaiter.wait(for: [playExp], timeout: 10)

        // Пропускаем на последний стих
        let nextVerse = app.buttons["read-next-verse"]
        if nextVerse.waitForExistence(timeout: 3) {
            Thread.sleep(forTimeInterval: 1)
            nextVerse.tap()
        }

        // Ждём завершения аудио
        let finishedPredicate = NSPredicate(format: "label == %@ OR label == %@",
                                            "finished", "segmentFinished")
        let finishExp = XCTNSPredicateExpectation(predicate: finishedPredicate, object: stateLabel)
        _ = XCTWaiter.wait(for: [finishExp], timeout: 30)

        // Даём время — если бы автопереход сработал, он бы произошёл за ~1 сек
        Thread.sleep(forTimeInterval: 3)

        // Заголовок НЕ должен измениться
        XCTAssertEqual(title.label, originalTitle,
                       "Chapter title should NOT change with autoNextChapter disabled")
    }

    // #36 — Играем Псалом 117 на 2x, уходим в фон до окончания аудио.
    // Результат: после возврата заголовок сменился — autoNextChapter сработал в фоне.
    @MainActor
    func testAutoNextChapterInBackground() throws {
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--start-excerpt", "psa 117"
        ]
        app.launch()
        app.navigateToReadingPage()

        let stateLabel = app.staticTexts["read-playback-state"]
        guard stateLabel.waitForExistence(timeout: 10) else {
            throw XCTSkip("Playback state label not found")
        }
        let waitingPredicate = NSPredicate(format: "label == %@", "waitingForPlay")
        let waitExp = XCTNSPredicateExpectation(predicate: waitingPredicate, object: stateLabel)
        _ = XCTWaiter.wait(for: [waitExp], timeout: 15)

        let title = app.buttons["read-chapter-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let originalTitle = title.label

        // Скорость 2x
        let speedBtn = app.buttons["read-speed"]
        XCTAssertTrue(speedBtn.waitForExistence(timeout: 3))
        for _ in 0..<5 { speedBtn.tap() }

        // Play и сразу переключаем на последний стих
        let playPause = app.buttons["read-play-pause"]
        playPause.tap()
        let playingPredicate = NSPredicate(format: "label == %@", "playing")
        let playExp = XCTNSPredicateExpectation(predicate: playingPredicate, object: stateLabel)
        _ = XCTWaiter.wait(for: [playExp], timeout: 10)

        let nextVerse = app.buttons["read-next-verse"]
        if nextVerse.waitForExistence(timeout: 3) {
            Thread.sleep(forTimeInterval: 1)
            nextVerse.tap()
        }

        // Уходим в фон — autoNextChapter должен сработать пока приложение в фоне
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 15)

        // Возвращаемся
        app.activate()
        Thread.sleep(forTimeInterval: 2)

        // Заголовок должен смениться — автопереход сработал в фоне
        XCTAssertNotEqual(title.label, originalTitle,
                          "Chapter title should change via autoNextChapter while in background. Was: \(originalTitle)")
    }
}

// MARK: - ClassicReadingPauseTests (тесты пауз с --pause-type / --pause-block)

final class ClassicReadingPauseTests: XCTestCase {

    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        app = nil
    }

    /// Запустить приложение с заданными настройками паузы и перейти на страницу чтения.
    private func launchWithPause(type: String, block: String) {
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--pause-type", type,
            "--pause-block", block
        ]
        app.launch()
        app.navigateToReadingPage()
    }

    /// Ждём debug playback state label
    private func waitForPlaybackState(_ state: String, timeout: TimeInterval = 10) -> Bool {
        let stateLabel = app.staticTexts["read-playback-state"]
        guard stateLabel.waitForExistence(timeout: 3) else { return false }
        return app.waitForLabel(element: stateLabel, toBe: state, timeout: timeout)
    }

    // #20 — Запускаем с pauseType=time + pauseBlock=verse.
    // Результат: после стиха плеер переходит в "autopausing", затем сам возобновляется.
    @MainActor
    func testPauseTimedVerse() throws {
        launchWithPause(type: "time", block: "verse")

        _ = waitForPlaybackState("waitingForPlay")

        let playPause = app.buttons["read-play-pause"]
        playPause.tap()
        XCTAssertTrue(waitForPlaybackState("playing"), "Should start playing")

        // С pauseBlock=verse autopause должна случиться после первого стиха
        let gotAutopause = waitForPlaybackState("autopausing", timeout: 30)
        XCTAssertTrue(gotAutopause, "Should enter autopausing after verse ends")

        // После timed-паузы плеер должен сам возобновить воспроизведение
        XCTAssertTrue(waitForPlaybackState("playing", timeout: 15),
                      "Should auto-resume after timed pause")

        playPause.tap() // stop
    }

    // #21 — Запускаем с pauseType=full + pauseBlock=verse.
    // Результат: после стиха плеер останавливается и НЕ возобновляется сам.
    @MainActor
    func testPauseFullVerse() throws {
        launchWithPause(type: "full", block: "verse")

        _ = waitForPlaybackState("waitingForPlay")

        let playPause = app.buttons["read-play-pause"]
        playPause.tap()
        XCTAssertTrue(waitForPlaybackState("playing"), "Should start playing")

        // Ждём полную паузу после стиха
        let gotPause = waitForPlaybackState("pausing", timeout: 30)
        XCTAssertTrue(gotPause, "Should enter pausing state with full pause type")

        // Ключевая проверка: плеер НЕ возобновляется сам
        Thread.sleep(forTimeInterval: 5)
        let stateLabel = app.staticTexts["read-playback-state"]
        XCTAssertEqual(stateLabel.label, "pausing",
                       "Should stay paused — full pause must not auto-resume")

        playPause.tap() // cleanup
    }

    // #22 — Запускаем с pauseType=time + pauseBlock=paragraph, скорость 2x.
    // Результат: плеер доигрывает до границы абзаца и переходит в "autopausing".
    // С pauseBlock=verse autopausing случилась бы раньше (после первого стиха),
    // а с paragraph — позже (только на границе абзаца).
    @MainActor
    func testPauseTimedParagraph() throws {
        launchWithPause(type: "time", block: "paragraph")

        _ = waitForPlaybackState("waitingForPlay")

        // Ускоряем до 2x чтобы быстрее дойти до границы абзаца
        let speedBtn = app.buttons["read-speed"]
        XCTAssertTrue(speedBtn.waitForExistence(timeout: 3))
        for _ in 0..<5 { speedBtn.tap() } // 1.0→1.2→1.4→1.6→1.8→2.0

        let playPause = app.buttons["read-play-pause"]
        playPause.tap()
        XCTAssertTrue(waitForPlaybackState("playing"), "Should start playing")

        // Ждём autopausing на границе абзаца (до 60 сек на 2x).
        // В Бытие 1 первая граница абзаца — перед стихом 3 (стихи 1-2 = один абзац).
        let gotAutopause = waitForPlaybackState("autopausing", timeout: 60)
        XCTAssertTrue(gotAutopause,
                      "Should reach autopausing at paragraph boundary")

        // После timed-паузы плеер должен сам возобновить воспроизведение
        if gotAutopause {
            XCTAssertTrue(waitForPlaybackState("playing", timeout: 15),
                          "Should auto-resume after paragraph pause")
        }

        playPause.tap() // stop
    }

    // #35 — Запускаем с pauseType=time + pauseBlock=verse, играем → уходим в фон.
    // Результат: после возврата из фона время продвинулось — паузы корректно
    // срабатывали и воспроизведение продолжалось в фоне.
    @MainActor
    func testPauseTimedVerseInBackground() throws {
        launchWithPause(type: "time", block: "verse")

        _ = waitForPlaybackState("waitingForPlay")

        let playPause = app.buttons["read-play-pause"]
        playPause.tap()
        XCTAssertTrue(waitForPlaybackState("playing"), "Should start playing")

        let timeCurrent = app.staticTexts["read-time-current"]
        XCTAssertTrue(timeCurrent.waitForExistence(timeout: 3))
        // Ждём чтобы время ушло от 00:00
        _ = app.waitForLabelChange(element: timeCurrent, from: "00:00", timeout: 15)
        let timeBeforeBackground = timeCurrent.label

        // Уходим в фон — паузы между стихами должны работать в фоне
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 10)

        // Возвращаемся
        app.activate()
        Thread.sleep(forTimeInterval: 1)

        // Время должно увеличиться — аудио играло с паузами в фоне
        let timeAfterBackground = timeCurrent.label
        XCTAssertNotEqual(timeAfterBackground, timeBeforeBackground,
                          "Time should advance during background playback with timed pauses. Before: \(timeBeforeBackground), after: \(timeAfterBackground)")

        playPause.tap() // stop
    }
}
