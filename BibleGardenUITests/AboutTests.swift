import XCTest

// MARK: - AboutTests (requires live API for dynamic content)

final class AboutTests: XCTestCase {

    private var app: XCUIApplication!
    private let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    private static var apiChecked = false
    private static var apiAvailable = true

    override func setUpWithError() throws {
        continueAfterFailure = false

        if !Self.apiChecked {
            Self.apiChecked = true
            Self.apiAvailable = checkAPIAvailability()
        }

        try XCTSkipUnless(Self.apiAvailable, "API unavailable — skipping about tests")

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.navigateViaMenu(to: "menu-contacts")

        let aboutPage = app.otherElements["page-about"]
        XCTAssertTrue(app.waitForElement(aboutPage, timeout: 5), "About page did not appear")
    }

    override func tearDownWithError() throws {
        // Ссылка открывается в Safari поверх приложения. Уборка здесь, а не в теле
        // теста: при падении тело до неё не доходит, и следующий тест не может
        // завершить приложение, оставшееся в фоне за Safari.
        // app == nil — тест пропущен до запуска, ссылку он не открывал.
        if app != nil, safari.state != .notRunning {
            safari.terminate()
            app.activate()
        }
        app = nil
    }

    // MARK: - Tests

    // #1 — Открываем страницу «О проекте» через меню.
    // Результат: страница `page-about` отображается.
    @MainActor
    func testAboutPageOpens() {
        let aboutPage = app.otherElements["page-about"]
        XCTAssertTrue(aboutPage.exists, "About page background should exist")
    }

    // #2 — Ждём загрузки контактов из API.
    // Результат: кнопки `contacts-telegram` и `contacts-website` видны.
    @MainActor
    func testContactButtonsExist() {
        let telegram = app.buttons["contacts-telegram"]
        let website = app.buttons["contacts-website"]

        XCTAssertTrue(app.waitForElement(telegram, timeout: 10), "Telegram contact button should exist")
        XCTAssertTrue(app.waitForElement(website, timeout: 10), "Website contact button should exist")
    }

    // #3 — Проверяем наличие текста «О приложении».
    // Результат: на странице есть текст, содержащий «Bible Garden».
    @MainActor
    func testAboutTextExists() {
        let predicate = NSPredicate(format: "label CONTAINS 'Bible Garden'")
        let aboutText = app.staticTexts.matching(predicate).firstMatch
        XCTAssertTrue(app.waitForElement(aboutText, timeout: 10), "About text containing 'Bible Garden' should be visible")
    }

    // #4 — Тап по кнопке Telegram открывает внешнюю ссылку.
    // Результат: ссылка t.me открывается в Safari (Telegram в симуляторе не установлен).
    // Проверяется Safari, а не состояние приложения: в фоне iOS быстро замораживает
    // приложение, и короткое `runningBackground` опрос может не застать.
    @MainActor
    func testTelegramButtonOpensLink() {
        let telegram = app.buttons["contacts-telegram"]
        XCTAssertTrue(app.waitForElement(telegram, timeout: 10), "Telegram button should exist")

        telegram.tap()

        // Первый запуск Safari на CI занимает до ~6 с.
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 10),
                      "Safari should open the Telegram link")
    }
}
