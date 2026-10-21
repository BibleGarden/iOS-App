import XCTest

// MARK: - NowPlayingOwnershipTests (Now Playing owner, #52-#54)

final class NowPlayingOwnershipTests: XCTestCase {

    private var app: XCUIApplication!
    private static var apiChecked = false
    private static var apiAvailable = true

    @MainActor override func setUpWithError() throws {
        continueAfterFailure = false

        if !Self.apiChecked {
            Self.apiChecked = true
            Self.apiAvailable = checkAPIAvailability()
        }

        try XCTSkipUnless(Self.apiAvailable, "API unavailable — skipping Now Playing ownership tests")

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--multi-template", "default"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Wait until the element exists and becomes enabled
    private func waitForEnabled(_ element: XCUIElement, timeout: TimeInterval = 20) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isEnabled { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        return false
    }

    // #52 — Обычное чтение владеет Now Playing: команды Play/Pause включены,
    // remote Pause останавливает воспроизведение, remote Play запускает его снова.
    // Результат: команды включены, статус команды — success, плеер реально встаёт на паузу и снова играет.
    @MainActor
    func testClassicReadingEnablesRemoteCommandsAndControlsPlayback() {
        app.navigateToReadingPage()
        XCTAssertTrue(app.waitForReadPlaybackState("waitingForPlay", timeout: 20),
                      "Classic playback should become ready before starting")

        let readPlayPause = app.buttons["read-play-pause"]
        XCTAssertTrue(waitForEnabled(readPlayPause), "Classic play button should be enabled")
        readPlayPause.tap()

        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-total-count", value: "1", timeout: 15),
                      "Classic playback should become active")
        XCTAssertTrue(app.waitForDebugNowPlayingOwner("classicRead", timeout: 10),
                      "Classic reading should own the Now Playing session. owner=\(app.debugValue("debug-now-playing-owner") ?? "nil")")
        XCTAssertTrue(app.waitForDebugRemoteCommandEnabled(true, timeout: 5),
                      "Play and pause commands should be enabled while the classic reading owns the session")

        // Remote Pause с экрана блокировки останавливает воспроизведение
        app.openMenu()

        let pauseStatus = app.sendDebugRemoteCommand(buttonIdentifier: "debug-menu-remote-pause")
        XCTAssertEqual(pauseStatus, "success",
                       "Remote pause with an owner should be handled. status=\(pauseStatus ?? "nil")")
        XCTAssertTrue(app.waitForReadPlaybackState("pausing", timeout: 10),
                      "Remote pause should stop the classic playback. state=\(app.debugValue("read-playback-state") ?? "nil")")
        XCTAssertTrue(app.waitForDebugPlayerActuallyPlaying(false, forOwner: "classicRead", timeout: 15),
                      "Classic AVPlayer should really pause after remote pause")

        // Remote Play снова запускает воспроизведение
        let playStatus = app.sendDebugRemoteCommand(buttonIdentifier: "debug-menu-remote-play")
        XCTAssertEqual(playStatus, "success",
                       "Remote play with an owner should be handled. status=\(playStatus ?? "nil")")
        XCTAssertTrue(app.waitForReadPlaybackState("playing", timeout: 15),
                      "Remote play should resume the classic playback. state=\(app.debugValue("read-playback-state") ?? "nil")")
        XCTAssertTrue(app.waitForDebugPlayerTimeControlStatus("playing", forOwner: "classicRead", timeout: 15),
                      "Classic AVPlayer should really play after remote play")
    }

    // #53 — Мультичтение владеет Now Playing: команды Play/Pause включены,
    // remote Pause останавливает чтение, remote Play продолжает его.
    // Результат: команды включены, статус команды — success, чтение реально встаёт на паузу и снова играет.
    @MainActor
    func testMultilingualReadingEnablesRemoteCommandsAndControlsPlayback() {
        app.navigateToMultiReadingPage()

        let multiPlayPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(waitForEnabled(multiPlayPause), "Multilingual play button should be enabled")
        multiPlayPause.tap()

        // Ждём реального старта аудио (AVPlayer играет), а не только логического состояния
        XCTAssertTrue(app.waitForDebugPlayerTimeControlStatus("playing", forOwner: "multilingualRead", timeout: 30),
                      "Multilingual playback should really start. state=\(app.debugValue("multi-playback-state") ?? "nil")")
        XCTAssertTrue(app.waitForDebugNowPlayingState("playing", timeout: 15),
                      "The player that owns the session should be playing. state=\(app.debugValue("debug-now-playing-state") ?? "nil")")
        XCTAssertTrue(app.waitForDebugNowPlayingOwner("multilingualRead", timeout: 10),
                      "Multilingual reading should own the Now Playing session. owner=\(app.debugValue("debug-now-playing-owner") ?? "nil")")
        XCTAssertTrue(app.waitForDebugRemoteCommandEnabled(true, timeout: 5),
                      "Play and pause commands should be enabled while the multilingual reading owns the session")

        // Remote Pause с экрана блокировки останавливает чтение
        let pauseStatus = app.sendDebugRemoteCommand(buttonIdentifier: "debug-remote-pause")
        XCTAssertEqual(pauseStatus, "success",
                       "Remote pause with an owner should be handled. status=\(pauseStatus ?? "nil")")
        XCTAssertTrue(app.waitForMultiPlaybackState("pausing", timeout: 10),
                      "Remote pause should stop the multilingual reading. state=\(app.debugValue("multi-playback-state") ?? "nil")")

        // Логическое состояние выставляется сразу, а аудио останавливается после
        // плавной паузы — ждём её окончания и проверяем состояние самого плеера.
        XCTAssertTrue(app.waitForDebugNowPlayingState(excluding: ["playing", "waitingForPause"], timeout: 15),
                      "The smooth pause should be finished. state=\(app.debugValue("debug-now-playing-state") ?? "nil")")
        XCTAssertTrue(app.waitForDebugPlayerActuallyPlaying(false, forOwner: "multilingualRead", timeout: 15),
                      "Multilingual AVPlayer should really pause after the smooth pause")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-total-count", value: "0", timeout: 10),
                      "No player should stay active after the remote pause. count=\(app.debugValue("debug-playback-total-count") ?? "nil")")

        // Remote Play продолжает чтение
        let playStatus = app.sendDebugRemoteCommand(buttonIdentifier: "debug-remote-play")
        XCTAssertEqual(playStatus, "success",
                       "Remote play with an owner should be handled. status=\(playStatus ?? "nil")")
        XCTAssertTrue(app.waitForMultiPlaybackState("playing", timeout: 20),
                      "Remote play should resume the multilingual reading. state=\(app.debugValue("multi-playback-state") ?? "nil")")
        XCTAssertTrue(app.waitForDebugPlayerTimeControlStatus("playing", forOwner: "multilingualRead", timeout: 20),
                      "Multilingual AVPlayer should really play after remote play")
    }

    // #54 — Обычное чтение → мультичтение → уход из мультичтения → команда Play с экрана блокировки.
    // Результат: владелец Now Playing переходит от обычного чтения к мультичтению,
    // после ухода из чтения владельца и nowPlayingInfo нет, команды Play/Pause выключены,
    // а команда Play ничего не запускает (нет активных плееров).
    @MainActor
    func testRemotePlayDoesNothingAfterLeavingReading() {
        // 1. Обычное чтение забирает Now Playing
        app.navigateToReadingPage()
        XCTAssertTrue(app.waitForReadPlaybackState("waitingForPlay", timeout: 20),
                      "Classic playback should become ready before starting")

        let readPlayPause = app.buttons["read-play-pause"]
        XCTAssertTrue(waitForEnabled(readPlayPause), "Classic play button should be enabled")
        readPlayPause.tap()

        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-total-count", value: "1", timeout: 15),
                      "Classic playback should become active")
        XCTAssertTrue(app.waitForDebugNowPlayingOwner("classicRead", timeout: 10),
                      "Classic reading should own the Now Playing session. owner=\(app.debugValue("debug-now-playing-owner") ?? "nil")")
        XCTAssertTrue(app.waitForDebugRemoteCommandEnabled(true, timeout: 5),
                      "Play and pause commands should be enabled while the classic reading owns the session")

        // 2. Мультичтение перехватывает Now Playing
        app.navigateToMultiReadingPage()

        let multiPlayPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(waitForEnabled(multiPlayPause), "Multilingual play button should be enabled")
        multiPlayPause.tap()

        XCTAssertTrue(app.waitForMultiPlaybackState("playing", timeout: 30),
                      "Multilingual playback should start")
        XCTAssertTrue(app.waitForDebugPlayerTimeControlStatus("playing", forOwner: "multilingualRead", timeout: 30),
                      "The multilingual AVPlayer should really start")
        XCTAssertTrue(app.waitForDebugNowPlayingOwner("multilingualRead", timeout: 10),
                      "Multilingual reading should own the Now Playing session. owner=\(app.debugValue("debug-now-playing-owner") ?? "nil")")
        XCTAssertTrue(app.waitForDebugNowPlayingInfoPresent(true, timeout: 5),
                      "Now Playing info should be published for the owner")
        XCTAssertTrue(app.waitForDebugRemoteCommandEnabled(true, timeout: 5),
                      "Play and pause commands should be enabled while the multilingual reading owns the session")

        // 3. Уход из мультичтения освобождает Now Playing
        app.navigateViaMenu(to: "menu-main")

        XCTAssertTrue(app.waitForDebugNowPlayingOwner("none", timeout: 10),
                      "Now Playing should be released after leaving the reading. owner=\(app.debugValue("debug-now-playing-owner") ?? "nil")")
        XCTAssertTrue(app.waitForDebugNowPlayingInfoPresent(false, timeout: 5),
                      "Now Playing info should be cleared after leaving the reading")
        XCTAssertTrue(app.waitForDebugPlaybackCount(identifier: "debug-playback-total-count", value: "0", timeout: 10),
                      "No player should stay active after leaving the reading")
        XCTAssertTrue(app.waitForDebugRemoteCommandEnabled(false, timeout: 5),
                      "Play and pause commands should be disabled while there is no owner")

        // 4. Команда Play с экрана блокировки ничего не запускает
        app.openMenu()

        let playStatus = app.sendDebugRemoteCommand(buttonIdentifier: "debug-menu-remote-play")
        XCTAssertEqual(playStatus, "noActionableNowPlayingItem",
                       "Remote play without an owner should be reported as not actionable. status=\(playStatus ?? "nil")")
        // Отсутствие запуска проверяется по фактической телеметрии всех экземпляров:
        // ни один AVPlayer не перешёл в воспроизведение.
        XCTAssertTrue(app.assertNoPlayerIsActuallyPlaying("Remote play should not start any player"),
                      "Remote play should not start any player")
        XCTAssertTrue(app.waitForDebugNowPlayingOwner("none", timeout: 5),
                      "Remote play should not claim the Now Playing session")
    }
}
