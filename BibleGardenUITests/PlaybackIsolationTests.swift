import XCTest

final class PlaybackIsolationTests: XCTestCase {

    private var app: XCUIApplication!
    private static var apiChecked = false
    private static var apiAvailable = true

    override func setUpWithError() throws {
        continueAfterFailure = false

        if !Self.apiChecked {
            Self.apiChecked = true
            Self.apiAvailable = checkAPIAvailability()
        }

        try XCTSkipUnless(Self.apiAvailable, "API unavailable — skipping playback isolation tests")

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "default"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // Переходим в обычное чтение, запускаем playback, затем уходим в мультичтение.
    // Результат: classic playback останавливается, а новый multilingual playback можно запустить отдельно.
    @MainActor
    func testClassicPlaybackStopsWhenSwitchingToMultilingualReading() {
        app.navigateToReadingPage()
        XCTAssertTrue(app.waitForReadPlaybackState("waitingForPlay", timeout: 15),
                      "Classic playback should become ready before starting")

        let readPlayPause = app.buttons["read-play-pause"]
        XCTAssertTrue(readPlayPause.waitForExistence(timeout: 5), "Classic play button should exist")
        readPlayPause.tap()

        let readState = app.staticTexts["read-playback-state"]
        XCTAssertTrue(readState.waitForExistence(timeout: 3), "Classic playback state label should exist")
        // Фактическое воспроизведение подтверждается состоянием AVPlayer.
        XCTAssertTrue(app.waitForDebugPlayerTimeControlStatus("playing", forOwner: "classicRead", timeout: 30),
                      "The classic AVPlayer should really start")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-total-count", value: "1", timeout: 5))
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-classic-count", value: "1", timeout: 5))
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-multilingual-count", value: "0", timeout: 5))

        app.navigateToMultiReadingPage()

        // Классическое воспроизведение остановлено: экземпляр освобождён
        // (отдельное условие) и ни один AVPlayer не играет.
        XCTAssertTrue(app.waitForDebugPlayerPlaybackState(.removed, forOwner: "classicRead", timeout: 10),
                      "The classic player instance should be released after leaving the page")
        XCTAssertTrue(app.assertNoPlayerIsActuallyPlaying("No playback should remain after leaving classic reading"),
                      "No AVPlayer should keep playing after leaving classic reading")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-classic-count", value: "0", timeout: 10),
                      "Classic playback should stop after leaving the page")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-total-count", value: "0", timeout: 10),
                      "No playback should remain active after leaving classic reading")

        let multiPlayPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(multiPlayPause.waitForExistence(timeout: 5), "Multilingual play button should exist")
        multiPlayPause.tap()

        XCTAssertTrue(app.waitForDebugPlayerTimeControlStatus("playing", forOwner: "multilingualRead", timeout: 30),
                      "Multilingual playback should really start")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-total-count", value: "1", timeout: 5))
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-classic-count", value: "0", timeout: 5))
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-multilingual-count", value: "1", timeout: 5))
    }

    // Запускаем обычное чтение, уходим на главную и возвращаемся обратно в обычное чтение.
    // Результат: старый classic pipeline не продолжает играть в фоне и не возобновляется сам после возврата.
    @MainActor
    func testClassicPlaybackDoesNotResumeAfterLeavingAndReturning() {
        app.navigateToReadingPage()
        XCTAssertTrue(app.waitForReadPlaybackState("waitingForPlay", timeout: 15),
                      "Classic playback should become ready before starting")

        let readPlayPause = app.buttons["read-play-pause"]
        XCTAssertTrue(readPlayPause.waitForExistence(timeout: 5), "Classic play button should exist")
        readPlayPause.tap()

        let readState = app.staticTexts["read-playback-state"]
        XCTAssertTrue(readState.waitForExistence(timeout: 3), "Classic playback state label should exist")
        XCTAssertTrue(app.waitForDebugPlayerTimeControlStatus("playing", forOwner: "classicRead", timeout: 30),
                      "The classic AVPlayer should really start")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-classic-count", value: "1", timeout: 5))

        app.navigateViaMenu(to: "menu-main")

        let mainCard = app.buttons["card-classic-reading"]
        XCTAssertTrue(mainCard.waitForExistence(timeout: 5), "Main page should appear")
        // Экземпляр классического плеера освобождён — это отдельное условие,
        // а не «тишина» вместо паузы.
        XCTAssertTrue(app.waitForDebugPlayerPlaybackState(.removed, forOwner: "classicRead", timeout: 10),
                      "The classic player instance should be released after leaving to the main page")
        XCTAssertTrue(app.assertNoPlayerIsActuallyPlaying("No playback should remain on the main page"),
                      "No AVPlayer should keep playing on the main page")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-classic-count", value: "0", timeout: 10),
                      "Classic playback should stop after leaving to main page")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-total-count", value: "0", timeout: 10),
                      "No playback should remain active on the main page")

        app.navigateToReadingPage()

        // Возврат не должен возобновлять старое воспроизведение: новый экземпляр
        // жив, но AVPlayer не играет.
        XCTAssertTrue(app.waitForDebugPlayerPlaybackState(.stopped, forOwner: "classicRead", timeout: 10),
                      "Returning to classic reading should not auto-resume old playback")
        XCTAssertTrue(app.assertNoPlayerIsActuallyPlaying("Old classic pipeline should not wake up in the background"),
                      "Old classic pipeline should not wake up in the background")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-classic-count", value: "0", timeout: 5),
                      "Returning to classic reading should not auto-resume old playback")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-total-count", value: "0", timeout: 5),
                      "Returning to classic reading should keep total active playback at zero")

        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertEqual(app.debugPlaybackCount("debug-playback-total-count"), "0",
                       "Old classic pipeline should not wake up in the background")
        XCTAssertTrue(app.assertNoPlayerIsActuallyPlaying("Old classic pipeline should not wake up in the background"),
                      "Old classic pipeline should not wake up in the background")

        XCTAssertTrue(app.waitForReadPlaybackState("waitingForPlay", timeout: 15),
                      "Classic playback should return to the ready state without auto-start")

        let readPlayPauseAfterReturn = app.buttons["read-play-pause"]
        XCTAssertTrue(readPlayPauseAfterReturn.waitForExistence(timeout: 5), "Classic play button should exist after return")
        readPlayPauseAfterReturn.tap()

        XCTAssertTrue(app.waitForDebugPlayerTimeControlStatus("playing", forOwner: "classicRead", timeout: 30),
                      "The classic AVPlayer should really start again on demand")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-total-count", value: "1", timeout: 5))
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-classic-count", value: "1", timeout: 5))
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-multilingual-count", value: "0", timeout: 5))
    }

    // Запускаем обычное чтение, быстро уходим на главную и сразу возвращаемся обратно в обычное чтение.
    // Результат: после повторного запуска classic playback не поднимаются два classic pipeline одновременно.
    @MainActor
    func testClassicPlaybackDoesNotOverlapAfterQuickReturnFromMain() {
        app.navigateToReadingPage()
        XCTAssertTrue(app.waitForReadPlaybackState("waitingForPlay", timeout: 15),
                      "Classic playback should become ready before starting")

        let firstPlayPause = app.buttons["read-play-pause"]
        XCTAssertTrue(firstPlayPause.waitForExistence(timeout: 5), "Classic play button should exist")
        firstPlayPause.tap()

        let readState = app.staticTexts["read-playback-state"]
        XCTAssertTrue(readState.waitForExistence(timeout: 3), "Classic playback state label should exist")
        XCTAssertTrue(app.waitForDebugPlayerTimeControlStatus("playing", forOwner: "classicRead", timeout: 30),
                      "The classic AVPlayer should really start")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-classic-count", value: "1", timeout: 5))

        app.navigateViaMenu(to: "menu-main")

        let mainCard = app.buttons["card-classic-reading"]
        XCTAssertTrue(mainCard.waitForExistence(timeout: 5), "Main page should appear")
        XCTAssertTrue(app.waitForDebugPlayerPlaybackState(.removed, forOwner: "classicRead", timeout: 10),
                      "Classic player instance should be released after leaving to the main page")
        XCTAssertTrue(app.assertNoPlayerIsActuallyPlaying("No playback should remain on the main page"),
                      "No AVPlayer should keep playing on the main page")

        let classicCard = app.buttons["card-classic-reading"]
        XCTAssertTrue(classicCard.waitForExistence(timeout: 5), "Classic reading card should exist on the main page")
        classicCard.tap()
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-live-classic-count", value: "1", timeout: 10),
                      "Returning to classic reading should create exactly one live classic player")
        XCTAssertTrue(app.waitForReadPlaybackState("waitingForPlay", timeout: 15),
                      "Classic playback should become ready again after return")

        let secondPlayPause = app.buttons["read-play-pause"]
        XCTAssertTrue(secondPlayPause.waitForExistence(timeout: 5), "Classic play button should exist after return")
        secondPlayPause.tap()

        XCTAssertTrue(app.waitForDebugPlayerTimeControlStatus("playing", forOwner: "classicRead", timeout: 30),
                      "The classic AVPlayer should really start again on demand")

        // Перекрытие проверяется по фактическим экземплярам AVPlayer:
        // одновременно играть могут не более одного.
        XCTAssertTrue(app.assertAtMostOnePlayerPlaying(owner: "classicRead", duration: 5),
                      "Classic playback should never overlap with an older classic pipeline after quick return")
        XCTAssertTrue(app.assertAtMostOnePlayerPlaying(duration: 5),
                      "Total active playback should not exceed one after restarting classic playback")
    }

    // Переходим в мультичтение, запускаем playback, затем уходим в обычное чтение.
    // Результат: multilingual playback останавливается, а новый classic playback можно запустить отдельно.
    @MainActor
    func testMultilingualPlaybackStopsWhenSwitchingToClassicReading() {
        app.navigateToMultiReadingPage()

        let multiPlayPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(multiPlayPause.waitForExistence(timeout: 5), "Multilingual play button should exist")
        multiPlayPause.tap()

        // Сначала дожидаемся фактического воспроизведения (готовности аудио),
        // и только потом сверяем логические счётчики: иначе проверка зависит
        // от скорости сети и может сработать на «до запуска».
        XCTAssertTrue(app.waitForDebugPlayerTimeControlStatus("playing", forOwner: "multilingualRead", timeout: 30),
                      "Multilingual playback should really start before switching")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-total-count", value: "1", timeout: 5))
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-multilingual-count", value: "1", timeout: 5))
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-classic-count", value: "0", timeout: 5))

        app.navigateToReadingPage()

        // Мультичтение остановлено: ни один AVPlayer не играет.
        XCTAssertTrue(app.waitForDebugPlayerNotPlaying(forOwner: "multilingualRead", timeout: 10),
                      "Multilingual playback should stop after leaving the page")
        XCTAssertTrue(app.assertNoPlayerIsActuallyPlaying("No playback should remain after leaving multilingual reading"),
                      "No AVPlayer should keep playing after leaving multilingual reading")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-multilingual-count", value: "0", timeout: 10),
                      "Multilingual playback should stop after leaving the page")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-total-count", value: "0", timeout: 10),
                      "No playback should remain active after leaving multilingual reading")

        let readPlayPause = app.buttons["read-play-pause"]
        XCTAssertTrue(readPlayPause.waitForExistence(timeout: 5), "Classic play button should exist")
        // Ждём готовности аудио: пока идёт буферизация, команда play игнорируется.
        XCTAssertTrue(app.waitForReadPlaybackState("waitingForPlay", timeout: 20),
                      "Classic playback should become ready before starting")
        readPlayPause.tap()

        let readState = app.staticTexts["read-playback-state"]
        XCTAssertTrue(readState.waitForExistence(timeout: 3), "Classic playback state label should exist")
        XCTAssertTrue(app.waitForDebugPlayerTimeControlStatus("playing", forOwner: "classicRead", timeout: 30),
                      "The classic AVPlayer should really start")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-total-count", value: "1", timeout: 5))
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-classic-count", value: "1", timeout: 5))
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-multilingual-count", value: "0", timeout: 5))
    }

    // Запускаем мультичтение, уходим на главную и возвращаемся обратно в мультичтение.
    // Результат: старый multilingual pipeline не продолжает играть в фоне и не возобновляется сам после возврата.
    @MainActor
    func testMultilingualPlaybackDoesNotResumeAfterLeavingAndReturning() {
        app.navigateToMultiReadingPage()

        let multiPlayPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(multiPlayPause.waitForExistence(timeout: 5), "Multilingual play button should exist")
        multiPlayPause.tap()

        // Сначала дожидаемся фактического воспроизведения, потом сверяем
        // логические счётчики: иначе проверка зависит от скорости сети.
        XCTAssertTrue(app.waitForDebugPlayerTimeControlStatus("playing", forOwner: "multilingualRead", timeout: 30),
                      "Multilingual playback should really start before leaving")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-total-count", value: "1", timeout: 5))
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-multilingual-count", value: "1", timeout: 5))

        app.navigateViaMenu(to: "menu-main")

        let mainCard = app.buttons["card-classic-reading"]
        XCTAssertTrue(mainCard.waitForExistence(timeout: 5), "Main page should appear")
        XCTAssertTrue(app.waitForDebugPlayerNotPlaying(forOwner: "multilingualRead", timeout: 10),
                      "Multilingual playback should stop after leaving to main page")
        XCTAssertTrue(app.assertNoPlayerIsActuallyPlaying("No playback should remain on the main page"),
                      "No AVPlayer should keep playing on the main page")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-multilingual-count", value: "0", timeout: 10),
                      "Multilingual playback should stop after leaving to main page")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-total-count", value: "0", timeout: 10),
                      "No playback should remain active on the main page")

        // Историю запусков фиксируем до возврата: сам возврат не должен
        // добавить ни одного запуска воспроизведения.
        let transitionsBeforeReturn = app.debugPlayingTransitionCount(forOwner: "multilingualRead")

        // Возврат к мультичтению — без перезапуска приложения: перезапуск убил бы
        // старые плееры и отложенные callback'и, а тест проверяет именно возврат
        // в том же процессе. Помощник идёт по настройке только тогда, когда меню
        // действительно открыло её: лишний уход стёр бы ошибочный автозапуск.
        app.returnToMultiReadingPageWithoutRestart()

        XCTAssertTrue(app.waitForDebugPlayerNotPlaying(forOwner: "multilingualRead", timeout: 10),
                      "Returning to multilingual reading should not auto-resume old playback")
        XCTAssertTrue(app.assertNoPlayerIsActuallyPlaying("Old multilingual pipeline should not wake up in the background"),
                      "Old multilingual pipeline should not wake up in the background")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-multilingual-count", value: "0", timeout: 5),
                      "Returning to multilingual reading should not auto-resume old playback")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-total-count", value: "0", timeout: 5),
                      "Returning to multilingual reading should keep total active playback at zero")

        // Старый pipeline не должен просыпаться в фоне: за интервал наблюдения
        // не было ни одного нового запуска воспроизведения.
        XCTAssertTrue(app.assertNoPlayerStartedPlaying(duration: 5),
                      "Old multilingual pipeline should not wake up in the background")
        XCTAssertEqual(app.debugPlayingTransitionCount(forOwner: "multilingualRead"), transitionsBeforeReturn,
                       "Old multilingual pipeline should not wake up in the background")
        XCTAssertTrue(app.assertNoPlayerIsActuallyPlaying("Old multilingual pipeline should not wake up in the background"),
                      "Old multilingual pipeline should not wake up in the background")

        let multiPlayPauseAfterReturn = app.buttons["multi-play-pause"]
        XCTAssertTrue(multiPlayPauseAfterReturn.waitForExistence(timeout: 5), "Multilingual play button should exist after return")
        multiPlayPauseAfterReturn.tap()

        XCTAssertTrue(app.waitForDebugPlayerTimeControlStatus("playing", forOwner: "multilingualRead", timeout: 30),
                      "Multilingual playback should really start again on demand")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-total-count", value: "1", timeout: 5))
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-multilingual-count", value: "1", timeout: 5))
    }
}
