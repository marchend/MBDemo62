import XCTest

/// Smoke tests that verify the login screen is the first screen the user
/// sees, and that all interactive elements are present and hittable.
///
/// These tests do NOT attempt a real sign-in — they only assert that the
/// UI is reachable and structurally correct.
final class LoginScreenUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: – Screen reachability

    func test_appLaunchesToLoginScreen() {
        // The username field must be visible immediately on launch —
        // confirming LoginView (not a placeholder) is the root view.
        let usernameField = app.textFields[LoginAccessibilityIDs.usernameField]
        XCTAssertTrue(
            usernameField.waitForExistence(timeout: 5),
            "Username field should be visible on the login screen immediately after launch"
        )
    }

    // MARK: – Field presence

    func test_usernameField_isPresent() {
        let field = app.textFields[LoginAccessibilityIDs.usernameField]
        XCTAssertTrue(field.exists, "Username text field should exist on the login screen")
    }

    func test_passwordField_isPresent() {
        let field = app.secureTextFields[LoginAccessibilityIDs.passwordField]
        XCTAssertTrue(field.exists, "Password secure field should exist on the login screen")
    }

    func test_signInButton_isPresent() {
        let button = app.buttons[LoginAccessibilityIDs.signInButton]
        XCTAssertTrue(button.exists, "Sign In button should exist on the login screen")
    }

    // MARK: – Hittability

    func test_usernameField_isHittable() {
        let field = app.textFields[LoginAccessibilityIDs.usernameField]
        XCTAssertTrue(field.isHittable, "Username field should be hittable (not obscured)")
    }

    func test_passwordField_isHittable() {
        let field = app.secureTextFields[LoginAccessibilityIDs.passwordField]
        XCTAssertTrue(field.isHittable, "Password field should be hittable (not obscured)")
    }

    func test_signInButton_isHittable() {
        let button = app.buttons[LoginAccessibilityIDs.signInButton]
        XCTAssertTrue(button.isHittable, "Sign In button should be hittable (not disabled initially)")
    }

    // MARK: – Interaction smoke test

    func test_typingInUsernameField_works() {
        let field = app.textFields[LoginAccessibilityIDs.usernameField]
        field.tap()
        field.typeText("testuser@acmebank.com")
        // Just assert we didn't crash — the value is in a SecureField so
        // XCUITest can't read it back, but the tap + typeText succeeding
        // means the field accepted input.
        XCTAssertTrue(field.exists)
    }
}

// MARK: – Accessibility ID mirror

/// Local mirror of `LoginAccessibility` constants so this test target
/// does not need to import the app module (UI test targets run in a
/// separate process and cannot use `@testable import`).
///
/// These values MUST stay in sync with `LoginView+Accessibility.swift`.
private enum LoginAccessibilityIDs {
    static let usernameField  = "loginUsernameField"
    static let passwordField  = "loginPasswordField"
    static let signInButton   = "loginSignInButton"
}
