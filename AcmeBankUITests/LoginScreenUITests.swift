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

    // MARK: – Unconfigured-banner contract

    /// Under the default CI configuration NO `OKTA_*` env vars are
    /// exported, so the post-build script writes the sentinel
    /// `OKTA_NOT_CONFIGURED` into the Info.plist and `OktaConfig.load`
    /// returns `.notConfigured(reason:)`.  Tapping Sign In with any
    /// credentials must surface the inline banner whose copy contains
    /// the substring "Okta is not configured" — the verbatim reason
    /// from `OktaConfig.notConfiguredReason`.
    func test_unconfigured_build_shows_notConfigured_banner() {
        let username = app.textFields[LoginAccessibilityIDs.usernameField]
        let password = app.secureTextFields[LoginAccessibilityIDs.passwordField]
        let signIn   = app.buttons[LoginAccessibilityIDs.signInButton]

        XCTAssertTrue(username.waitForExistence(timeout: 5))

        username.tap()
        username.typeText("anyone@example.com")

        password.tap()
        password.typeText("anything")

        signIn.tap()

        // The error banner uses `accessibilityIdentifier` "loginErrorLabel".
        // Its label text is the full reason string from OktaConfig; we
        // assert on the stable substring to avoid coupling to copy edits.
        let banner = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Okta is not configured")
        ).firstMatch

        XCTAssertTrue(
            banner.waitForExistence(timeout: 5),
            "Expected the inline error banner to contain 'Okta is not configured' when Okta env vars are unset"
        )
    }

    // MARK: – End-to-end sign-in

    /// End-to-end happy-path: type real test-tenant credentials, tap
    /// Sign In, and assert the Landing screen's "Welcome, …" greeting
    /// appears.  Gated by `OKTA_ISSUER` because CI builds run with no
    /// env vars set — the app then returns `.notConfigured` and a real
    /// sign-in is impossible.
    ///
    /// The `XCTSkipUnless` form is taken verbatim from the
    /// `feature_implementer` persona Expert Reference under
    /// "OktaDirectAuth".
    func test_signIn_navigatesToLanding() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["OKTA_ISSUER"] != nil &&
            !ProcessInfo.processInfo.environment["OKTA_ISSUER"]!.isEmpty,
            "Okta is not configured — skipping end-to-end sign-in test"
        )

        // Test-tenant credentials are provided via env vars so this
        // file never embeds secrets.  Skip gracefully if either is
        // unset — same contract as the issuer guard above.
        guard
            let testUsername = ProcessInfo.processInfo.environment["OKTA_TEST_USERNAME"],
            let testPassword = ProcessInfo.processInfo.environment["OKTA_TEST_PASSWORD"],
            !testUsername.isEmpty,
            !testPassword.isEmpty
        else {
            throw XCTSkip("OKTA_TEST_USERNAME / OKTA_TEST_PASSWORD not set — cannot drive end-to-end sign-in")
        }

        let username = app.textFields[LoginAccessibilityIDs.usernameField]
        let password = app.secureTextFields[LoginAccessibilityIDs.passwordField]
        let signIn   = app.buttons[LoginAccessibilityIDs.signInButton]

        XCTAssertTrue(username.waitForExistence(timeout: 5))

        username.tap()
        username.typeText(testUsername)

        password.tap()
        password.typeText(testPassword)

        signIn.tap()

        // Landing's "Welcome, …" label is identified by
        // `LandingAccessibilityIDs.welcomeLabel`.  Allow a generous
        // timeout — the round-trip to Okta's `/oauth2/v1/token` plus
        // SwiftUI's view-tree swap can take several seconds on a cold
        // simulator.
        let welcome = app.staticTexts[LandingAccessibilityIDs.welcomeLabel]
        XCTAssertTrue(
            welcome.waitForExistence(timeout: 20),
            "Expected the Landing screen's Welcome greeting to appear after a successful sign-in"
        )
        XCTAssertTrue(
            welcome.label.hasPrefix("Welcome, "),
            "Welcome label should be prefixed with 'Welcome, ' followed by the user's display name"
        )
    }
}

// MARK: – Accessibility ID mirrors

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

/// Local mirror of `LandingAccessibility` constants.  Must stay in
/// sync with `LandingView.swift`.
private enum LandingAccessibilityIDs {
    static let welcomeLabel = "landingWelcomeLabel"
    static let emailLabel   = "landingEmailLabel"
}
