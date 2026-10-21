import XCTest

// MARK: - BookSelectTests (requires live API)

/// Проверяет фильтр книг по частям Библии на экране выбора книги.
/// Ожидаемый результат: ВЗ содержит книги 1..39 (включая Малахию, 39),
/// НЗ содержит книги 40..66 (начиная с Матфея, 40).
final class BookSelectTests: XCTestCase {

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

        try XCTSkipUnless(Self.apiAvailable, "API unavailable — skipping book select tests")

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        app.navigateToReadingPage()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Ветхий / Новый Завет

    @MainActor
    func testBookSelectTestamentFilter() {
        // Открываем sheet выбора книги/главы через тап по заголовку главы
        let titleBtn = app.buttons["read-chapter-title"]
        XCTAssertTrue(titleBtn.waitForExistence(timeout: 5),
                      "Reading page chapter title should appear")
        titleBtn.tap()

        // Sheet выбора книги появилась
        let selector = app.otherElements["testament-selector"]
        XCTAssertTrue(selector.waitForExistence(timeout: 5),
                      "Testament selector should appear in book select sheet")

        let malachi = app.buttons["book_39"]
        let matthew = app.buttons["book_40"]

        // MARK: Ветхий Завет — Малахия (39) есть, Матфея (40) нет
        tapTestamentSegment(on: selector, segment: 0)

        XCTAssertTrue(malachi.waitForExistence(timeout: 8),
                      "Malachi (book 39) should be shown in Old Testament")
        XCTAssertTrue(matthew.waitForNonExistence(timeout: 5),
                      "Matthew (book 40) should not be shown in Old Testament")

        // MARK: Новый Завет — Матфея (40) есть, Малахии (39) нет
        tapTestamentSegment(on: selector, segment: 1)

        XCTAssertTrue(matthew.waitForExistence(timeout: 8),
                      "Matthew (book 40) should be shown in New Testament")
        XCTAssertTrue(malachi.waitForNonExistence(timeout: 5),
                      "Malachi (book 39) should not be shown in New Testament")

        // Закрываем sheet
        app.buttons["select-close"].tap()
    }

    // MARK: - Helpers

    /// Тапает сегмент selector-а testament (0 — ВЗ слева, 1 — НЗ справа) по координате.
    private func tapTestamentSegment(on selector: XCUIElement, segment: Int) {
        let normalizedX = segment == 0 ? 0.25 : 0.75
        selector.coordinate(withNormalizedOffset: CGVector(dx: normalizedX, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 0.6) // анимация и перерисовка фильтра книг
    }
}
