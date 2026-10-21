import XCTest

extension XCUIApplication {

    // MARK: - Menu

    /// Tap the hamburger button to open the side menu
    func openMenu() {
        let menuButton = buttons["menu-button"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "Menu button not found")
        menuButton.tap()

        let sideMenu = otherElements["side-menu"]
        XCTAssertTrue(sideMenu.waitForExistence(timeout: 3), "Side menu did not appear")
    }

    /// Tap a menu item by its accessibility identifier
    func tapMenuItem(_ identifier: String) {
        let item = buttons[identifier]
        XCTAssertTrue(item.waitForExistence(timeout: 3), "Menu item '\(identifier)' not found")
        item.tap()
    }

    /// Open menu and navigate to a page via menu item identifier
    func navigateViaMenu(to menuItemIdentifier: String) {
        openMenu()
        tapMenuItem(menuItemIdentifier)
    }

    // MARK: - Reading page

    /// Navigate to the classic reading page and wait for content to load
    func navigateToReadingPage() {
        navigateViaMenu(to: "menu-read")
        let title = buttons["read-chapter-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8),
                      "Reading page chapter title should appear")
    }

    func waitForReadPlaybackState(_ state: String, timeout: TimeInterval = 10) -> Bool {
        let stateLabel = staticTexts["read-playback-state"]
        guard stateLabel.waitForExistence(timeout: 3) else { return false }
        return waitForLabel(element: stateLabel, toBe: state, timeout: timeout)
    }

    func waitForReadHighlightedVerse(_ verseID: String, timeout: TimeInterval = 10) -> Bool {
        let webView = webViews.firstMatch
        if webView.waitForExistence(timeout: 3) {
            return waitForValue(element: webView, toBe: verseID, timeout: timeout)
        }

        let label = staticTexts["read-highlighted-verse-id"]
        guard label.waitForExistence(timeout: 3) else { return false }
        return waitForLabel(element: label, toBe: verseID, timeout: timeout)
    }

    func readHighlightedVerseID() -> String? {
        let webView = webViews.firstMatch
        if webView.waitForExistence(timeout: 3) {
            return webView.value as? String
        }

        let label = staticTexts["read-highlighted-verse-id"]
        guard label.waitForExistence(timeout: 3) else { return nil }
        return label.label
    }

    // MARK: - Text content

    /// Find the reading page text content (HTMLTextView wraps WKWebView,
    /// which shows up as `webViews` in XCUITest rather than `otherElements`)
    func waitForTextContent(timeout: TimeInterval = 10) -> XCUIElement? {
        let webView = webViews.firstMatch
        if webView.waitForExistence(timeout: timeout) {
            return webView
        }
        let other = otherElements["read-text-content"]
        if other.waitForExistence(timeout: 2) {
            return other
        }
        return nil
    }

    // MARK: - Waits

    /// Wait for an element to exist with a timeout, returns Bool
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }

    /// Wait for an element's label to change from a known value
    func waitForLabelChange(element: XCUIElement, from oldLabel: String, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label != %@", oldLabel)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Wait for an element's value to change from a known value
    func waitForValueChange(element: XCUIElement, from oldValue: String, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "value != %@", oldValue)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Wait for an element's label to equal a specific value
    func waitForLabel(element: XCUIElement, toBe label: String, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Wait for an element's value to equal a specific value
    func waitForValue(element: XCUIElement, toBe value: String, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    // MARK: - Multilingual Reading Helpers

    func navigateToMultiSetupPage() {
        navigateViaMenu(to: "menu-multilingual")
        let setupPage = otherElements["page-multi-setup"]
        XCTAssertTrue(waitForElement(setupPage, timeout: 5), "Multi setup page did not appear")
    }

    func navigateToMultiReadingPage() {
        navigateViaMenu(to: "menu-multilingual")
        let readingPage = otherElements["page-multi-reading"]
        XCTAssertTrue(waitForElement(readingPage, timeout: 10), "Multi reading page did not appear")
    }

    func waitForMultiTextContent(timeout: TimeInterval = 15) -> XCUIElement? {
        let webView = webViews.firstMatch
        if webView.waitForExistence(timeout: timeout) { return webView }
        let other = otherElements["multi-text-content"]
        if other.waitForExistence(timeout: 2) { return other }
        return nil
    }

    func waitForMultiPlaybackState(_ state: String, timeout: TimeInterval = 10) -> Bool {
        let stateLabel = staticTexts["multi-playback-state"]
        guard stateLabel.waitForExistence(timeout: 3) else { return false }
        return waitForLabel(element: stateLabel, toBe: state, timeout: timeout)
    }

    func multiCurrentUnit() -> String? {
        let label = staticTexts["multi-current-unit"]
        guard label.waitForExistence(timeout: 3) else { return nil }
        return label.label
    }

    func multiCurrentStep() -> String? {
        let label = staticTexts["multi-current-step"]
        guard label.waitForExistence(timeout: 3) else { return nil }
        return label.label
    }

    func waitForDebugPlaybackCount(identifier: String, value: String, timeout: TimeInterval = 10) -> Bool {
        let label = staticTexts[identifier]
        guard label.waitForExistence(timeout: 3) else { return false }
        return waitForLabel(element: label, toBe: value, timeout: timeout)
    }

    func debugPlaybackCount(_ identifier: String) -> String? {
        let label = staticTexts[identifier]
        guard label.waitForExistence(timeout: 3) else { return nil }
        return label.label
    }

    func debugPlaybackCountExceeds(
        identifier: String,
        threshold: Int,
        duration: TimeInterval,
        pollInterval: TimeInterval = 0.1
    ) -> Bool {
        let deadline = Date().addingTimeInterval(duration)
        while Date() < deadline {
            if let rawValue = debugPlaybackCount(identifier),
               let count = Int(rawValue),
               count > threshold {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        return false
    }

    // MARK: - Actual AVPlayer state (debug registry, только DEBUG-сборка)

    /// Читает из label JSON-словарь владельца → значение.
    private func debugDictionary(_ identifier: String) -> [String: Any]? {
        guard let raw = debugValue(identifier),
              let data = raw.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }

    /// AVPlayer timeControlStatus владельца: "playing" / "paused" / "waitingToPlay"
    func debugPlayerTimeControlStatus(forOwner owner: String) -> String? {
        debugDictionary("debug-player-time-control-status")?[owner] as? String
    }

    /// Играет ли AVPlayer владельца прямо сейчас (фактически, а не логически)
    func debugPlayerIsActuallyPlaying(forOwner owner: String) -> Bool? {
        debugDictionary("debug-player-is-actually-playing")?[owner] as? Int == 1
    }

    /// Сколько раз плеер владельца перешёл в .playing (включая неожидаемые запуски)
    func debugUnexpectedPlayStarts(forOwner owner: String) -> Int? {
        debugDictionary("debug-unexpected-play-starts")?[owner] as? Int
    }

    /// Дождаться заданного timeControlStatus у AVPlayer владельца
    @discardableResult
    func waitForDebugPlayerTimeControlStatus(_ status: String, forOwner owner: String, timeout: TimeInterval = 20) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if debugPlayerTimeControlStatus(forOwner: owner) == status { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("AVPlayer of '\(owner)' should be '\(status)' within \(Int(timeout))s, got '\(debugPlayerTimeControlStatus(forOwner: owner) ?? "nil")'")
        return false
    }

    /// Дождаться, пока AVPlayer владельца станет (не) играть фактически
    @discardableResult
    func waitForDebugPlayerActuallyPlaying(_ isPlaying: Bool, forOwner owner: String, timeout: TimeInterval = 20) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if debugPlayerIsActuallyPlaying(forOwner: owner) == isPlaying { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("AVPlayer of '\(owner)' should be \(isPlaying ? "" : "not ")actually playing within \(Int(timeout))s")
        return false
    }

    /// Убедиться, что за интервал плеер владельца ни разу не начал играть
    /// (счётчик переходов в .playing не увеличился).
    @discardableResult
    func assertDebugPlayerDidNotStartPlaying(forOwner owner: String, duration: TimeInterval, pollInterval: TimeInterval = 1.0) -> Bool {
        let startsBefore = debugUnexpectedPlayStarts(forOwner: owner) ?? 0
        let deadline = Date().addingTimeInterval(duration)
        while Date() < deadline {
            let startsNow = debugUnexpectedPlayStarts(forOwner: owner) ?? 0
            if startsNow > startsBefore {
                XCTFail("AVPlayer of '\(owner)' started playing during the pause interval (starts \(startsBefore) → \(startsNow))")
                return false
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        return true
    }

    // MARK: - Now Playing debug helpers

    /// Read a debug value published by the app
    func debugValue(_ identifier: String) -> String? {
        let label = staticTexts[identifier]
        guard label.waitForExistence(timeout: 3) else { return nil }
        return label.label
    }

    /// Wait for the owner of the Now Playing session ("none", "classicRead", "multilingualRead", "other")
    func waitForDebugNowPlayingOwner(_ owner: String, timeout: TimeInterval = 10) -> Bool {
        let label = staticTexts["debug-now-playing-owner"]
        guard label.waitForExistence(timeout: 3) else { return false }
        return waitForLabel(element: label, toBe: owner, timeout: timeout)
    }

    /// Wait for the presence of the Now Playing info
    func waitForDebugNowPlayingInfoPresent(_ isPresent: Bool, timeout: TimeInterval = 10) -> Bool {
        let label = staticTexts["debug-now-playing-info-present"]
        guard label.waitForExistence(timeout: 3) else { return false }
        return waitForLabel(element: label, toBe: isPresent ? "1" : "0", timeout: timeout)
    }

    /// Wait for the state of the play/pause commands of the lock screen / Control Center
    func waitForDebugRemoteCommandEnabled(_ isEnabled: Bool, timeout: TimeInterval = 10) -> Bool {
        let playLabel = staticTexts["debug-remote-play-enabled"]
        let pauseLabel = staticTexts["debug-remote-pause-enabled"]
        guard playLabel.waitForExistence(timeout: 3),
              pauseLabel.waitForExistence(timeout: 3) else { return false }
        let expected = isEnabled ? "1" : "0"
        return waitForLabel(element: playLabel, toBe: expected, timeout: timeout)
            && waitForLabel(element: pauseLabel, toBe: expected, timeout: timeout)
    }

    /// Wait for the status of the last remote transport command
    func waitForDebugRemoteCommandStatus(_ status: String, timeout: TimeInterval = 10) -> Bool {
        let label = staticTexts["debug-remote-command-status"]
        guard label.waitForExistence(timeout: 3) else { return false }
        return waitForLabel(element: label, toBe: status, timeout: timeout)
    }

    /// Wait until more remote transport commands were emulated than before
    @discardableResult
    func waitForDebugRemoteCommandCount(greaterThan count: Int, timeout: TimeInterval = 15) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let rawValue = debugValue("debug-remote-command-count"),
               let value = Int(rawValue),
               value > count {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("The remote transport command should be handled within \(Int(timeout))s")
        return false
    }

    /// Emulate a remote transport command and wait until it was handled.
    /// Returns the status that the command handler reported.
    @discardableResult
    func sendDebugRemoteCommand(buttonIdentifier: String, timeout: TimeInterval = 15) -> String? {
        let button = buttons[buttonIdentifier]
        guard button.waitForExistence(timeout: 5) else {
            XCTFail("Debug remote command button '\(buttonIdentifier)' should exist")
            return nil
        }
        guard let rawCount = debugValue("debug-remote-command-count"),
              let handledBefore = Int(rawCount) else {
            XCTFail("The debug remote command counter should be published by the app")
            return nil
        }
        button.tap()
        guard waitForDebugRemoteCommandCount(greaterThan: handledBefore, timeout: timeout) else {
            return nil
        }
        return debugValue("debug-remote-command-status")
    }

    /// Wait until the state of the player that owns the Now Playing session
    /// reaches the given state.
    @discardableResult
    func waitForDebugNowPlayingState(_ state: String, timeout: TimeInterval = 15) -> Bool {
        let label = staticTexts["debug-now-playing-state"]
        guard label.waitForExistence(timeout: 3) else {
            XCTFail("The debug Now Playing state should be published by the app")
            return false
        }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if label.label == state { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("The Now Playing state should become '\(state)' within \(Int(timeout))s, got '\(label.label)'")
        return false
    }

    /// Wait until the state of the player that owns the Now Playing session is
    /// not one of the given states (for example while a smooth pause is over).
    @discardableResult
    func waitForDebugNowPlayingState(excluding states: [String], timeout: TimeInterval = 15) -> Bool {
        let label = staticTexts["debug-now-playing-state"]
        guard label.waitForExistence(timeout: 3) else {
            XCTFail("The debug Now Playing state should be published by the app")
            return false
        }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !states.contains(label.label) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("The Now Playing state should leave \(states.joined(separator: ", ")) within \(Int(timeout))s, got '\(label.label)'")
        return false
    }

    /// Дождаться, пока AVPlayer владельца начнёт играть, и сразу же прислать remote-паузу.
    /// Ловит короткий сегмент, пока он звучит, вместо фиксированного ожидания.
    /// Кнопка паузы проверяется в тесте до вызова хелпера, поэтому здесь не ждём её
    /// Appearance — любая лишняя задержка позволяет короткому стиху закончиться.
    @discardableResult
    func waitForPlayerPlayingAndPause(forOwner owner: String, pauseButtonIdentifier: String, timeout: TimeInterval = 30) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if debugPlayerTimeControlStatus(forOwner: owner) == "playing" {
                buttons[pauseButtonIdentifier].tap()
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("AVPlayer of '\(owner)' never started playing within \(Int(timeout))s")
        return false
    }

    /// Ожидает debug-now-playing-state без промежуточного waitForExistence.
    /// Элемент уже существует; любая лишняя задержка позволяет короткой фазе
    /// waitingForPause (≈0.3 с) пройти мимо, поэтому опрашиваем плотно сразу.
    @discardableResult
    func waitForDebugNowPlayingStateFast(_ state: String, timeout: TimeInterval = 5) -> Bool {
        let label = staticTexts["debug-now-playing-state"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if label.label == state { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTFail("The Now Playing state should become '\(state)' within \(Int(timeout))s, got '\(label.label)'")
        return false
    }
}

// MARK: - Shared API Health Check

/// Проверяет доступность API с повторными попытками (до 3 раз).
/// URL берётся из TestConfig.baseURL (xcconfig → Info.plist).
/// Возвращает true, если сервер ответил HTTP-статусом.
func checkAPIAvailability(maxAttempts: Int = 3) -> Bool {
    let urlString = "\(TestConfig.baseURL)/api/languages"
    guard let url = URL(string: urlString) else { return false }
    for attempt in 1...maxAttempts {
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse {
                success = (200...499).contains(http.statusCode)
            }
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + 15)
        if success { return true }
        if attempt < maxAttempts {
            Thread.sleep(forTimeInterval: 2)
        }
    }
    return false
}
