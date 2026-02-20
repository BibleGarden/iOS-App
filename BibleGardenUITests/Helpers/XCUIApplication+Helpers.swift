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

    // MARK: - Waits

    /// Wait for an element to exist with a timeout, returns Bool
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }
}
