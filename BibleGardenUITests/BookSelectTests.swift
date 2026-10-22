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

    /// Сценарий: выбрана глава другой книги (Лука, book_42 — прямо над Ин.),
    /// excerpt-запрос удерживается DEBUG-барьером (--excerpt-request-barrier +
    /// кнопка debug-menu-release-excerpt), поэтому currentExcerpt уже указывает
    /// на новую книгу, а currentBookId ещё на старую (Ин., book_43) — это
    /// проверяется по наблюдаемым debug-меткам. Повторное открытие выбора должно
    /// ставить список на новую книгу, раскрывать её главы, а ручной тап по книге
    /// должен отключать автораскрытие.
    @MainActor
    func testReopenWhileChapterLoadingPositionsAtNewBook() {
        app.terminate()
        app.launchArguments = ["--uitesting", "--excerpt-request-barrier"]
        app.launch()
        app.navigateToReadingPage()

        // Начальный запрос главы Ин. удерживается барьером — отпускаем его.
        app.openMenu()
        let releaseButton = app.buttons["debug-menu-release-excerpt"]
        XCTAssertTrue(releaseButton.waitForExistence(timeout: 5),
                      "The barrier release button should exist in the menu")
        releaseButton.tap()
        app.tapMenuItem("menu-read")
        XCTAssertTrue(app.waitForReadPlaybackReady(),
                      "Initial chapter (John) should load after the barrier release")

        // Первый визит: список загружается и встаёт на текущую книгу (Ин., book_43)
        let titleBtn = app.buttons["read-chapter-title"]
        XCTAssertTrue(titleBtn.waitForExistence(timeout: 5))
        titleBtn.tap()
        XCTAssertTrue(app.buttons["select-close"].waitForExistence(timeout: 5),
                      "Chapter selection sheet should appear")
        XCTAssertTrue(app.waitForElementHittable(app.buttons["book_43"], timeout: 20),
                      "First open should position the list at the current book (John)")

        // Лука (book_42) — прямо над Ин.: строка Ин. выровнена по верху списка,
        // поэтому чуть прокручиваем вверх. Тап по Лк. сворачивает грид Ин.,
        // поэтому кнопка главы "22" (в Ин. только 21 глава) однозначна.
        app.swipeDown()
        let luke = app.buttons["book_42"]
        XCTAssertTrue(app.waitForElementHittable(luke, timeout: 10),
                      "The book above John should be visible after scrolling up")
        luke.tap()
        let lukeChapter = app.buttons["22"]
        XCTAssertTrue(app.waitForElementHittable(lukeChapter, timeout: 10),
                      "Luke's chapter grid should appear")
        lukeChapter.tap()

        // Окно гонки открыто ровно столько, сколько нужно тесту:
        // запрос главы Луки удержан барьером, book id ещё старый.
        let barrierHeld = app.staticTexts["debug-excerpt-barrier-held"]
        XCTAssertTrue(barrierHeld.waitForExistence(timeout: 5))
        XCTAssertTrue(app.waitForLabel(element: barrierHeld, toBe: "1", timeout: 5),
                      "The excerpt request should be held by the barrier")
        XCTAssertEqual(app.debugValue("debug-current-book-id"), "43",
                       "The stale book id (John) proves the race window is open")

        // Повторное открытие выбора: список стоит на выбранной книге (Лука)
        // и раскрывает её главы, а не устаревшей (Ин.).
        XCTAssertTrue(titleBtn.waitForExistence(timeout: 5))
        titleBtn.tap()
        XCTAssertTrue(app.buttons["select-close"].waitForExistence(timeout: 5),
                      "Chapter selection sheet should reappear")
        XCTAssertTrue(app.waitForElementHittable(luke, timeout: 10),
                      "Reopened list should stand on the newly selected book (Luke), not on the stale one (John)")
        XCTAssertTrue(app.waitForElementHittable(lukeChapter, timeout: 10),
                      "Chapters of the newly selected book (Luke) should be expanded, not the stale book's (John)")

        // Ручной выбор книги всегда в приоритете: тап по Ин. (устаревший book id)
        // должен раскрыть её грид и закрыть грид Луки — иначе раскрыты обе.
        let john = app.buttons["book_43"]
        XCTAssertTrue(app.waitForElementHittable(john, timeout: 10),
                      "John's row should be visible below the expanded Luke grid")
        john.tap()
        XCTAssertTrue(app.waitForElementHittable(app.buttons["1"], timeout: 10),
                      "The manually tapped book's grid (John) should open")
        // Обе строки книг всегда есть в иерархии (список не ленив), поэтому
        // расстояние между ними — наблюдаемый признак раскрытого грида Лк.:
        // он занимает ~200pt между строками, закрытый грид — почти ничего.
        let gapAfterManualTap = john.frame.minY - luke.frame.maxY
        XCTAssertLessThanOrEqual(gapAfterManualTap, 100,
                                 "The manual tap on John must close the auto-expanded Luke grid (gap \(gapAfterManualTap)pt means both grids are expanded)")

        // Отпускаем барьер: удерживаемый запрос завершается, book id обновляется.
        let bookIdLabel = app.staticTexts["debug-current-book-id"]
        let closeButton = app.buttons["select-close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()
        app.openMenu()
        releaseButton.tap()
        app.tapMenuItem("menu-read")
        XCTAssertTrue(app.waitForLabel(element: bookIdLabel, toBe: "42", timeout: 30),
                      "The held Luke request should complete and update the book id after the release")
    }

    /// Жизненный цикл барьера: удерживаемый excerpt-запрос должен сниматься
    /// при уходе со страницы чтения. Запрос задачи onAppear снимается отменой
    /// задачи (withTaskCancellationHandler), а запрос по кнопке «следующая
    /// глава» никто не отменяет — его снимает только инвалидация сессии
    /// (cancelAll в shutdownPlaybackPipeline).
    @MainActor
    func testHeldExcerptRequestIsReleasedWhenLeavingReadPage() {
        app.terminate()
        app.launchArguments = ["--uitesting", "--excerpt-request-barrier"]
        app.launch()
        app.navigateToReadingPage()

        // Начальный запрос (задача onAppear) удержан барьером — отпускаем его.
        let barrierHeld = app.staticTexts["debug-excerpt-barrier-held"]
        XCTAssertTrue(barrierHeld.waitForExistence(timeout: 5))
        XCTAssertTrue(app.waitForLabel(element: barrierHeld, toBe: "1", timeout: 10),
                      "The initial excerpt request should be held by the barrier")
        app.openMenu()
        let releaseButton = app.buttons["debug-menu-release-excerpt"]
        XCTAssertTrue(releaseButton.waitForExistence(timeout: 5))
        releaseButton.tap()
        app.tapMenuItem("menu-read")
        XCTAssertTrue(app.waitForReadPlaybackReady(),
                      "Initial chapter should load after the barrier release")

        // Запрос по кнопке «следующая глава» тоже удерживается барьером.
        let nextButton = app.buttons["read-next-chapter"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.tap()
        XCTAssertTrue(app.waitForLabel(element: barrierHeld, toBe: "1", timeout: 10),
                      "The next-chapter request should be held by the barrier")

        // Уход со страницы чтения снимает и это ожидание: задача кнопки
        // не отменяется никем — её снимает только инвалидация сессии.
        app.navigateViaMenu(to: "menu-main")
        XCTAssertTrue(app.waitForLabel(element: barrierHeld, toBe: "0", timeout: 10),
                      "Leaving the reading page should resume the held request instead of leaving it suspended")
    }
}
