//
//  BibleGardenUITests.swift
//  BibleGardenUITests
//
//  Created by  Mac on 20.02.2026.
//

import XCTest

final class BibleGardenUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App Launch

    @MainActor
    func testAppLaunches() {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
