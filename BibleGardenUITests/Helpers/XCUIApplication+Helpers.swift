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

    /// Wait for an element's label to equal a specific value
    func waitForLabel(element: XCUIElement, toBe label: String, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
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
