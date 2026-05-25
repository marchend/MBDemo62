import SwiftUI

/// Post-authentication landing screen.
///
/// Renders the two human-readable claims taken from the user's ID
/// token — `displayName` ("name" claim) and `email` ("email" claim) —
/// straight off the injected `UserSession`.  There is intentionally
/// no network call here: every field is already in memory by the time
/// the composition root presents this view.
///
/// Story scope: this is the entire content of the landing screen for
/// now.  Real account / transaction widgets land in a later PR.
struct LandingView: View {

    /// In-memory snapshot of the signed-in user, supplied by the
    /// composition root (`AcmeBankApp`) via SwiftUI navigation state.
    let session: UserSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome, \(session.displayName)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color.primary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(LandingAccessibility.welcomeLabel)

            Text(session.email)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .accessibilityIdentifier(LandingAccessibility.emailLabel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 24)
        .padding(.top, 64)
        .background(Color(.systemBackground))
    }
}

// MARK: – Accessibility identifiers

/// Stable `accessibilityIdentifier` constants for the Landing screen.
///
/// `LoginScreenUITests.test_signIn_navigatesToLanding()` locates the
/// "Welcome, …" label via this identifier; keeping it as a typed
/// constant means a copy / layout change can never silently break the
/// XCUITest.
enum LandingAccessibility {
    /// "Welcome, {displayName}" greeting label.
    static let welcomeLabel = "landingWelcomeLabel"
    /// User's email address, rendered below the greeting.
    static let emailLabel   = "landingEmailLabel"
}

// MARK: – Preview

#Preview {
    LandingView(
        session: UserSession(
            userId:        "00uPREVIEW",
            displayName:   "Marc Henderson",
            email:         "marc@example.com",
            accessToken:   "preview",
            authTimestamp: Date(),
            deviceName:    "Preview Device"
        )
    )
}
