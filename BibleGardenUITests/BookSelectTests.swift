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

    // MARK: - Ветхий / Новый Завет / все книги

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

        // MARK: Ветхий Завет — книги 1…39 есть, 40…66 нет
        tapTestamentSegment(on: selector, segment: 0)

        for n in 1...39 {
            waitForBookPresent(n)
        }
        for n in 40...66 {
            XCTAssertFalse(app.buttons["book_\(n)"].exists,
                           "Книга book_\(n) не должна быть видна во Ветхом Завете")
        }

        // MARK: Новый Завет — книги 40…66 есть, 1…39 нет
        tapTestamentSegment(on: selector, segment: 1)

        for n in 40...66 {
            waitForBookPresent(n)
        }
        for n in 1...39 {
            XCTAssertFalse(app.buttons["book_\(n)"].exists,
                           "Книга book_\(n) не должна быть видна в Новом Завете")
        }

        // MARK: Повторный тап по НЗ снимает фильтр — книги обоих Заветов видны
        tapTestamentSegment(on: selector, segment: 1)

        for n in [1, 39, 40, 66] {
            waitForBookPresent(n)
        }

        // Закрываем sheet
        app.buttons["select-close"].tap()
    }

    // MARK: - Helpers

    /// Тапает сегмент testament (0 — ВЗ слева, 1 — НЗ справа) по координате.
    private func tapTestamentSegment(on selector: XCUIElement, segment: Int) {
        let normalizedX = segment == 0 ? 0.25 : 0.75
        selector.coordinate(withNormalizedOffset: CGVector(dx: normalizedX, dy: 0.5)).tap()
    }

    /// Прокручивает список книг вниз. Ожидание результата — проверка présence элемента,
    /// без фиксированного sleep.
    private func dragBooksDown() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    /// Ждёт появления книги в списке, прокручивая вниз до дедлайна.
    private func waitForBookPresent(_ n: Int) {
        let btn = app.buttons["book_\(n)"]
        let deadline = Date().addingTimeInterval(25)
        while Date() < deadline {
            if btn.exists { return }
            dragBooksDown()
        }
        XCTFail("Книга book_\(n) не видна в списке после прокрутки")
    }
}
