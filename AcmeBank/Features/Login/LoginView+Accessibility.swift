import Foundation

/// Stable `accessibilityIdentifier` constants for the Login screen.
///
/// Both `LoginView` and `LoginScreenUITests` reference these constants
/// so that a copy/layout change can never silently break the UI tests.
enum LoginAccessibility {
    /// Username / email text field.
    static let usernameField   = "loginUsernameField"
    /// Password secure field.
    static let passwordField   = "loginPasswordField"
    /// Primary "Sign In" button.
    static let signInButton    = "loginSignInButton"
    /// Inline error label shown when `errorMessage` is non-nil.
    static let errorLabel      = "loginErrorLabel"
    /// Branding header / title label.
    static let brandingHeader  = "loginBrandingHeader"
}
