//
//  SidebarTestSupport.swift
//  DSH-MizarUITests
//
//  Opening the sidebar, once, for every suite that needs it.
//
//  It was copied into four classes and every copy had the same hole: it tapped
//  `shell.sidebarToggle`, and the home page -- the conversation pane with no
//  conversation -- draws no navigation items, so on that screen the button is
//  not in the tree at all and the copy failed with "there is no way to open the
//  sidebar". The drawer's own gesture is the way in there, and it is the route
//  an operator has.
//

import XCTest

extension XCTestCase {
    /// Bring the sidebar out, if it is not out already.
    ///
    /// - Parameter app: the running app.
    func openSidebar(_ app: XCUIApplication) {
        let marker = app.buttons["sessions.new"]
        if marker.exists, marker.isHittable { return }

        let toggle = app.buttons["shell.sidebarToggle"]
        if !toggle.waitForExistence(timeout: 5) {
            // A system dialog that arrived late covers the shell and eats the
            // tap. Dismiss it and look once more.
            Self.dismissAnySystemAlert(app)
        }
        if toggle.waitForExistence(timeout: 3), toggle.isHittable {
            toggle.tap()
        } else {
            // No navigation item on this screen: the drawer's own swipe.
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.45))
            let finish = app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.47))
            start.press(forDuration: 0.05, thenDragTo: finish)
        }

        let shown = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND hittable == true"),
            object: marker,
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [shown], timeout: 20),
            .completed,
            "the sidebar did not open",
        )
    }
}

extension XCTestCase {
    /// Tap the first button of a system alert, when one is covering the app.
    ///
    /// - Parameter app: the app under test.
    static func dismissAnySystemAlert(_ app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow", "Don’t Allow", "Don't Allow", "OK"] where springboard.buttons[label].exists {
            springboard.buttons[label].tap()
            return
        }
    }
}
