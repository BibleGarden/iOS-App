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

    /// Declining the consent sends nothing; service failures, a network timeout, no connection,
    /// an empty answer and the rate limit each show their own state.
    @MainActor
    func testFailuresEmptyAnswerAndRateLimit() {
        // Each search request takes the next answer, so the first request after the declined
        // consent getting the first answer proves that declining sent nothing.
        launch(outcomes: [
            Outcome(status: 503, body: Self.errorResponse),
            Outcome(urlError: URLError.Code.timedOut.rawValue),
            Outcome(urlError: URLError.Code.notConnectedToInternet.rawValue),
            Outcome(body: Self.emptyResponse),
            Outcome(status: 429, retryAfter: "3", body: Self.errorResponse),
        ])
        openSearch()
        submit(query)
        let decline = app.buttons["search-consent-decline"]
        XCTAssertTrue(decline.waitForExistence(timeout: 5), "The first search should ask for AI consent")
        decline.tap()
        XCTAssertFalse(app.staticTexts["Finding relevant passages"].waitForExistence(timeout: 2),
                       "Declining the consent should not start a search")

        submit()
        allowConsent()
        assertError("The search service is unavailable")

        submit()
        assertError("The search took too long")

        submit()
        assertError("Couldn’t reach the server")

        submit()
        XCTAssertTrue(app.staticTexts["No matching passages"].waitForExistence(timeout: 10),
                      "An empty answer should show the empty state, not an error")

        submit()
        assertError("The search limit has been reached")
        let countdown = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Try again in'")).firstMatch
        XCTAssertTrue(countdown.exists, "The field should count down the Retry-After seconds")
        XCTAssertFalse(app.buttons["search-submit"].exists, "Searching again should wait for Retry-After")
        XCTAssertTrue(app.buttons["search-submit"].waitForExistence(timeout: 6),
                      "Searching should be possible again once Retry-After has passed")
    }

    /// The answer to a replaced query arrives after the new results and must not replace them;
    /// "Listen" on a passage without audio opens the reader with the warning and plays nothing.
    @MainActor
    func testLateAnswerKeepsNewResultsAndListenWithoutAudio() {
        launch(extraArguments: ["--force-no-audio"], outcomes: [
            Outcome(delaySeconds: 4, body: Self.emptyResponse),
            Outcome(),
        ])
        openSearch()
        submit(query)
        allowConsent()
        XCTAssertTrue(app.staticTexts["Finding relevant passages"].waitForExistence(timeout: 5), "The first search should be running")

        submit(" Noah")
        XCTAssertTrue(resultActions.firstMatch.waitForExistence(timeout: 10), "The new query should get its results")
        XCTAssertFalse(app.staticTexts["No matching passages"].waitForExistence(timeout: 6),
                       "The late empty answer of the replaced query should be ignored")
        XCTAssertTrue(resultActions.firstMatch.exists, "The results of the new query should stay")

        openCardAction("Listen")
        XCTAssertTrue(app.descendants(matching: .any)["read-audio-warning-panel"].firstMatch.waitForExistence(timeout: 15),
                      "The reader should warn that the passage has no audio")
        XCTAssertFalse(app.buttons["read-play-pause"].isEnabled, "Play should be disabled without audio")
        XCTAssertFalse(app.waitForReadPlaybackState("playing", timeout: 3), "Nothing should play without audio")
    }

    // MARK: - Steps

    /// A scripted answer of the search request, see `RecordedSearchTransport` in the app.
    private struct Outcome: Encodable {
        var status: Int?
        var retryAfter: String?
        var delaySeconds: Double?
        var urlError: Int?
        var body: String?
    }

    private static let emptyResponse = #"{"language":"en","translation":16,"results":[]}"#
    private static let errorResponse = #"{"detail":"Scripted failure"}"#

    private func launch(extraArguments: [String] = [], outcomes: [Outcome]? = nil) {
        app = XCUIApplication()
        // The recorded response is for BSB: the search starts with the translation of the
        // device language, so the device runs in English whatever the simulator locale is.
        app.launchArguments = ["--uitesting", "--app-language", "en",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extraArguments
        app.launchEnvironment["UITEST_SEARCH_RESPONSE"] = Self.recordedResponse
        if let outcomes {
            app.launchEnvironment["UITEST_SEARCH_OUTCOMES"] = String(decoding: try! JSONEncoder().encode(outcomes), as: UTF8.self)
        }
        app.launch()
    }

    private func openSearch() {
        let entry = app.buttons["card-search"]
        XCTAssertTrue(app.waitForElementHittable(entry, timeout: 10), "Home search field not found")
        entry.tap()
        XCTAssertTrue(app.textFields["search-query"].waitForExistence(timeout: 5), "Search field not found")
    }

    /// Appends `text` to the query and submits it from the keyboard.
    private func submit(_ text: String = "") {
        let field = app.textFields["search-query"]
        field.tap()
        field.typeText(text + "\n")
    }

    private func allowConsent() {
        let allow = app.buttons["search-consent-allow"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5), "The first search should ask for AI consent")
        allow.tap()
    }

    private func assertError(_ detailPrefix: String) {
        let detail = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", detailPrefix)).firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 10),
                      "Expected the error '\(detailPrefix)…', got \(app.staticTexts.allElementsBoundByIndex.map(\.label))")
    }

    /// Types the query from the home search field, accepts the AI consent and waits for the results.
    private func searchFromHome() {
        openSearch()
        submit(query)

        allowConsent()

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
