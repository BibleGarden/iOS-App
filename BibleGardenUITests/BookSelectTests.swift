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

    // MARK: - Повторное открытие во время загрузки выбранной главы

    /// Сценарий: выбрана глава другой книги (Псалтирь), excerpt-запрос удерживается
    /// DEBUG-флагом --excerpt-request-delay, поэтому currentExcerpt уже указывает
    /// на новую книгу, а currentBookId ещё на старую (Ин.). Повторное открытие
    /// выбора должно ставить список на новую книгу.
    @MainActor
    func testReopenWhileChapterLoadingPositionsAtNewBook() {
        app.terminate()
        app.launchArguments = ["--uitesting", "--excerpt-request-delay", "10"]
        app.launch()
        app.navigateToReadingPage()
        XCTAssertTrue(app.waitForReadPlaybackReady(),
                      "Initial chapter (John) should load before the scenario")

        // Первый визит: список загружается и встаёт на текущую книгу (Ин., book_43)
        let titleBtn = app.buttons["read-chapter-title"]
        XCTAssertTrue(titleBtn.waitForExistence(timeout: 5))
        titleBtn.tap()
        XCTAssertTrue(app.buttons["select-close"].waitForExistence(timeout: 5),
                      "Chapter selection sheet should appear")
        XCTAssertTrue(app.waitForElementHittable(app.buttons["book_43"], timeout: 20),
                      "First open should position the list at the current book (John)")

        // Прокручиваем список к началу до Псалтири (book_19). Тап по книге
        // сворачивает грид Ин., поэтому кнопка главы "1" однозначна.
        let psalms = app.buttons["book_19"]
        var swipes = 0
        while !(psalms.exists && psalms.isHittable) && swipes < 6 {
            app.swipeDown()
            swipes += 1
        }
        XCTAssertTrue(psalms.isHittable, "Psalms row should be scrolled into view")
        psalms.tap()

        let psalmsChapterOne = app.buttons["1"]
        XCTAssertTrue(app.waitForElementHittable(psalmsChapterOne, timeout: 10),
                      "Psalms chapter grid should appear")
        psalmsChapterOne.tap()

        // Запрос главы Псалтири удерживается: currentExcerpt уже "psa 1",
        // currentBookId всё ещё 43. Сразу открываем выбор снова — список
        // должен стоять на выбранной книге, а не на устаревшей.
        XCTAssertTrue(titleBtn.waitForExistence(timeout: 5))
        titleBtn.tap()
        XCTAssertTrue(app.buttons["select-close"].waitForExistence(timeout: 5),
                      "Chapter selection sheet should reappear")
        XCTAssertTrue(app.waitForElementHittable(psalms, timeout: 10),
                      "Reopened list should stand on the newly selected book (Psalms), not on the stale one (John)")
    }
}
