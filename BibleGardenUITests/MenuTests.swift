import XCTest

final class MenuTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Menu basics

    @MainActor
    func testMenuOpensShowsAllItemsAndCloses() {
        app.openMenu()

        let sideMenu = app.otherElements["side-menu"]
        XCTAssertTrue(sideMenu.exists, "Side menu should be visible after opening")

        // Main should be selected by default
        let mainItem = app.buttons["menu-main"]
        XCTAssertTrue(mainItem.waitForExistence(timeout: 3))
        XCTAssertTrue(mainItem.isSelected, "Main should be selected on app launch")

        // All 6 items present
        let expectedItems = [
            "menu-main",
            "menu-multilingual",
            "menu-read",
            "menu-progress",
            "menu-language",
            "menu-contacts"
        ]
        for identifier in expectedItems {
            let item = app.buttons[identifier]
            XCTAssertTrue(item.waitForExistence(timeout: 3),
                          "Menu item '\(identifier)' should exist")
        }

        // Tap an item → menu closes
        app.tapMenuItem("menu-main")
        let menuDisappeared = sideMenu.waitForNonExistence(timeout: 3)
            || !sideMenu.isHittable
        XCTAssertTrue(menuDisappeared, "Side menu should close after tapping an item")
    }

    // MARK: - Navigation (order matches menu items)

    // 1. Multilingual
    @MainActor
    func testNavigateToMultiReadingAndBack() {
        app.navigateViaMenu(to: "menu-multilingual")

        // Should land on either setup or read page
        let multiSetup = app.otherElements["page-multi-setup"]
        let multiRead = app.otherElements["page-multi-reading"]
        let onMultiPage = multiSetup.waitForExistence(timeout: 5)
            || multiRead.waitForExistence(timeout: 3)
        XCTAssertTrue(onMultiPage,
                      "Should navigate to a multilingual page (setup or read)")

        // Check highlight
        app.openMenu()
        let multiItem = app.buttons["menu-multilingual"]
        XCTAssertTrue(multiItem.waitForExistence(timeout: 3))
        XCTAssertTrue(multiItem.isSelected, "Multilingual should be selected")

        // Return to main
        app.tapMenuItem("menu-main")
        let mainCard = app.buttons["card-classic-reading"]
        XCTAssertTrue(mainCard.waitForExistence(timeout: 5),
                      "Should return to main page from multilingual")
    }

    // 3. Classic Reading
    @MainActor
    func testNavigateToClassicReadingAndBack() {
        app.navigateViaMenu(to: "menu-read")

        let readTitle = app.otherElements["read-chapter-title"]
            .waitForExistence(timeout: 5)
            || app.buttons["read-chapter-title"]
                .waitForExistence(timeout: 3)
        XCTAssertTrue(readTitle, "Read page should show chapter title")

        // Check highlight
        app.openMenu()
        let readItem = app.buttons["menu-read"]
        XCTAssertTrue(readItem.waitForExistence(timeout: 3))
        XCTAssertTrue(readItem.isSelected, "Classic Reading should be selected")

        // Return to main
        app.tapMenuItem("menu-main")
        let mainCard = app.buttons["card-classic-reading"]
        XCTAssertTrue(mainCard.waitForExistence(timeout: 5),
                      "Should return to main page from read page")
    }

    // 4. Progress
    @MainActor
    func testNavigateToProgressAndBack() {
        app.navigateViaMenu(to: "menu-progress")

        let progressElement = app.staticTexts["progress-total"]
        XCTAssertTrue(progressElement.waitForExistence(timeout: 5),
                      "Progress page should show total progress")

        // Check highlight
        app.openMenu()
        let progressItem = app.buttons["menu-progress"]
        XCTAssertTrue(progressItem.waitForExistence(timeout: 3))
        XCTAssertTrue(progressItem.isSelected, "Progress should be selected")

        // Return to main
        app.tapMenuItem("menu-main")
        let mainCard = app.buttons["card-classic-reading"]
        XCTAssertTrue(mainCard.waitForExistence(timeout: 5),
                      "Should return to main page from progress page")
    }

    // 5. Language
    @MainActor
    func testLanguageSheetOpensAndCloses() {
        app.openMenu()
        app.tapMenuItem("menu-language")

        let languageSheet = app.otherElements["language-sheet"]
        XCTAssertTrue(languageSheet.waitForExistence(timeout: 3),
                      "Language selection sheet should appear")

        // Close the sheet
        let closeButton = app.buttons["language-close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3))
        closeButton.tap()

        // Menu button should be accessible again
        let menuButton = app.buttons["menu-button"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5),
                      "Menu button should be accessible after closing language sheet")
    }

    // 6. About
    @MainActor
    func testNavigateToAboutAndBack() {
        app.navigateViaMenu(to: "menu-contacts")

        let aboutPage = app.otherElements["page-about"]
        XCTAssertTrue(aboutPage.waitForExistence(timeout: 5),
                      "About page should appear")

        // Check highlight
        app.openMenu()
        let aboutItem = app.buttons["menu-contacts"]
        XCTAssertTrue(aboutItem.waitForExistence(timeout: 3))
        XCTAssertTrue(aboutItem.isSelected, "About should be selected")

        // Return to main
        app.tapMenuItem("menu-main")
        let mainCard = app.buttons["card-classic-reading"]
        XCTAssertTrue(mainCard.waitForExistence(timeout: 5),
                      "Should return to main page from about page")
    }
}
