//
//  DrakeUITests.swift
//  DrakeUITests
//

import XCTest

final class DrakeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// With no arguments the window opens on the history browser.
    @MainActor
    func testHistoryWindowOpens() throws {
        let app = XCUIApplication()
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["Search files and folders"].exists)
        XCTAssertTrue(app.buttons["Close"].exists)
    }

    /// The window opens inside the bounded width rather than stretching to fit paths.
    @MainActor
    func testWindowWidthIsBounded() throws {
        let app = XCUIApplication()
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        XCTAssertLessThanOrEqual(window.frame.width, 900)
        XCTAssertGreaterThanOrEqual(window.frame.width, 360)
    }
}
