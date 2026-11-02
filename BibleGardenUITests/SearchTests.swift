import XCTest

// MARK: - SearchTests (requires the live API for translations and reading)

/// The search itself answers with a recorded API response (`Fixtures/`): the AI search
/// of the test API is too unstable for CI, and its quality is not what these tests check.
final class SearchTests: XCTestCase {

    private var app: XCUIApplication!
    private static var apiChecked = false
    private static var apiAvailable = true

    /// The recorded response answers this question with Genesis 6, Hebrews 11 and 1 Peter 3.
    private let query = "Who built the ark?"
    private static let recordedResponse: String = {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/search-who-built-the-ark.json")
        return try! String(contentsOf: fixture, encoding: .utf8)
    }()

    override func setUpWithError() throws {
        continueAfterFailure = false

        if !Self.apiChecked {
            Self.apiChecked = true
            Self.apiAvailable = checkAPIAvailability()
        }

        try XCTSkipUnless(Self.apiAvailable, "API unavailable — skipping search tests")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tests

    /// Home search field → results → "Read the chapter" marks the key verses →
    /// back to the same results → history replaces the examples → withdrawing consent deletes it.
    @MainActor
    func testSearchResultOpensChapterAndKeepsHistory() {
        launch()
        searchFromHome()

        openCardAction("Read the chapter")
        XCTAssertTrue(app.buttons["read-chapter-title"].waitForExistence(timeout: 10),
                      "The reader should open the chapter of the result")
        assertKeyVerses(app.staticTexts["read-key-verses"])

        returnToResults()

        app.buttons["search-clear"].tap()
        let recent = app.buttons["search-recent"].firstMatch
        XCTAssertTrue(recent.waitForExistence(timeout: 5), "The submitted query should be in the history")
        XCTAssertTrue(recent.label.contains(query), "History should show the query, got '\(recent.label)'")
        XCTAssertFalse(app.buttons["search-example"].exists, "Examples should be hidden while there is history")

        app.buttons["search-privacy"].tap()
        let revoke = app.buttons["search-consent-revoke"]
        XCTAssertTrue(revoke.waitForExistence(timeout: 5), "The consent sheet should offer withdrawal")
        revoke.tap()
        XCTAssertTrue(app.buttons["search-example"].firstMatch.waitForExistence(timeout: 5),
                      "Withdrawing consent should delete the history and bring the examples back")
        XCTAssertFalse(app.buttons["search-recent"].exists, "History should be empty after withdrawal")
    }

    /// "Multi Reading" opens the passage in multilingual reading with the key verses marked;
    /// back returns to the results; "Clear" empties the history.
    @MainActor
    func testSearchResultOpensMultiReading() {
        launch(extraArguments: ["--multi-template", "default"])
        searchFromHome()

        openCardAction("Multi Reading")
        XCTAssertTrue(app.buttons["multi-chapter-title"].waitForExistence(timeout: 15),
                      "Multilingual reading should open the passage")
        assertKeyVerses(app.staticTexts["multi-key-verses"])

        returnToResults()

        app.buttons["search-clear"].tap()
        let clearHistory = app.buttons["search-recent-clear"]
        XCTAssertTrue(clearHistory.waitForExistence(timeout: 5), "History should offer clearing")
        clearHistory.tap()
        XCTAssertTrue(app.buttons["search-example"].firstMatch.waitForExistence(timeout: 5),
                      "Clearing the history should bring the examples back")
    }

    // MARK: - Steps

    private func launch(extraArguments: [String] = []) {
        app = XCUIApplication()
        // The recorded response is for BSB: the search starts with the translation of the
        // device language, so the device runs in English whatever the simulator locale is.
        app.launchArguments = ["--uitesting", "--app-language", "en",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extraArguments
        app.launchEnvironment["UITEST_SEARCH_RESPONSE"] = Self.recordedResponse
        app.launch()
    }

    /// Types the query from the home search field, accepts the AI consent and waits for the results.
    private func searchFromHome() {
        let entry = app.buttons["card-search"]
        XCTAssertTrue(app.waitForElementHittable(entry, timeout: 10), "Home search field not found")
        entry.tap()

        let field = app.textFields["search-query"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Search field not found")
        field.tap()
        field.typeText(query + "\n")

        let allow = app.buttons["search-consent-allow"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5), "The first search should ask for AI consent")
        allow.tap()

        let firstCard = resultActions.firstMatch
        let errorTitle = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Search couldn'")).firstMatch
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline, !firstCard.exists, !errorTitle.exists {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertFalse(errorTitle.exists,
                       "Search failed: \(app.staticTexts.allElementsBoundByIndex.map(\.label))")
        XCTAssertTrue(firstCard.exists, "Search results did not appear")

        let genesis = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Genesis 6:'")).firstMatch
        XCTAssertTrue(genesis.exists, "Genesis 6 should be among the results for '\(query)'")
    }

    private var resultActions: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'search-actions-'"))
    }

    private func openCardAction(_ title: String) {
        resultActions.firstMatch.tap()
        let item = app.buttons[title]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Card menu item '\(title)' not found")
        item.tap()
    }

    /// The reader reports the key verse range of the result, e.g. "14-16".
    private func assertKeyVerses(_ label: XCUIElement) {
        XCTAssertTrue(app.waitForLabelChange(element: label, from: "", timeout: 15),
                      "The reader should mark the key verses of the result")
        XCTAssertNotNil(label.label.range(of: #"^\d+-\d+$"#, options: .regularExpression),
                        "Unexpected key verse range '\(label.label)'")
    }

    private func returnToResults() {
        let back = app.buttons["read-back-search"]
        XCTAssertTrue(back.waitForExistence(timeout: 5), "A reader opened from search should offer the way back")
        back.tap()
        XCTAssertTrue(resultActions.firstMatch.waitForExistence(timeout: 5),
                      "Back should return to the same results")
    }
}
