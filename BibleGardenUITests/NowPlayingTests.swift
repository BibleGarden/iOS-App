import XCTest

// MARK: - NowPlayingOwnershipTests (Now Playing owner, #52)

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

    // #52 — Обычное чтение → мультичтение → уход из мультичтения → команда Play с экрана блокировки.
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

        // 2. Мультичтение перехватывает Now Playing
        app.navigateToMultiReadingPage()

        let multiPlayPause = app.buttons["multi-play-pause"]
        XCTAssertTrue(waitForEnabled(multiPlayPause), "Multilingual play button should be enabled")
        multiPlayPause.tap()

        XCTAssertTrue(app.waitForMultiPlaybackState("playing", timeout: 30),
                      "Multilingual playback should start")
        XCTAssertTrue(app.waitForDebugNowPlayingOwner("multilingualRead", timeout: 10),
                      "Multilingual reading should own the Now Playing session. owner=\(app.debugValue("debug-now-playing-owner") ?? "nil")")
        XCTAssertTrue(app.waitForDebugNowPlayingInfoPresent(true, timeout: 5),
                      "Now Playing info should be published for the owner")

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

        let remotePlay = app.buttons["debug-menu-remote-play"]
        XCTAssertTrue(remotePlay.waitForExistence(timeout: 5), "Debug remote play button should exist")
        remotePlay.tap()

        XCTAssertTrue(app.waitForDebugRemoteCommandStatus("noActionableNowPlayingItem", timeout: 10),
                      "Remote play without an owner should be reported as not actionable. status=\(app.debugValue("debug-remote-command-status") ?? "nil")")
        XCTAssertFalse(app.debugPlaybackCountExceeds(identifier: "debug-playback-total-count", threshold: 0, duration: 5, pollInterval: 0.5),
                       "Remote play should not start any player")
        XCTAssertTrue(app.waitForDebugNowPlayingOwner("none", timeout: 5),
                      "Remote play should not claim the Now Playing session")
    }
}
