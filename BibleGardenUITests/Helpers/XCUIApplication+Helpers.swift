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
