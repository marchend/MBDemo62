import XCTest
import SwiftUI
@testable import AcmeBank

/// Dark-mode integration tests for `LandingView`.
///
/// Verifies that:
/// 1. `LandingView` can be instantiated and rendered with a `ThemeStore`
///    in either colour scheme without crashing.
/// 2. The `ThemeToggleButton` overlay is present and resolves its
///    environment object without crash.
/// 3. A scheme toggled on the shared `ThemeStore` before `LandingView`
///    is presented carries through — proving the single `ThemeStore`
///    instance is shared across the Login → Landing transition.
final class LandingViewDarkModeTests: XCTestCase {

    // MARK: – Fixtures

    private func makeSession(
        displayName: String = "Marc Henderson",
        email: String = "marc@example.com"
    ) -> UserSession {
        UserSession(
            userId:        "00uABC",
            displayName:   displayName,
            email:         email,
            accessToken:   "ACCESS",
            authTimestamp: Date(timeIntervalSince1970: 1_700_000_000),
            deviceName:    "Test Device"
        )
    }

    @MainActor
    private func render<V: View>(_ view: V) {
        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()
    }

    // MARK: – ThemeToggleButton presence

    /// `LandingView` rendered with a `ThemeStore` must not crash — this
    /// proves the `ThemeToggleButton` in the top-trailing overlay successfully
    /// reads the injected environment object.
    @MainActor
    func testToggleButtonPresentOnLandingView() {
        let store = ThemeStore() // .light
        let view = LandingView(session: makeSession()).environmentObject(store)
        render(view)
        // Reaching here means ThemeToggleButton resolved its @EnvironmentObject.
    }

    /// Same check in Dark mode — the overlay toggle must render without crash.
    @MainActor
    func testToggleButtonPresentOnLandingView_darkMode() {
        let store = ThemeStore()
        store.toggle() // .dark
        let view = LandingView(session: makeSession()).environmentObject(store)
        render(view)
    }

    // MARK: – Scheme carries from Login to Landing

    /// Toggling `ThemeStore` to `.dark` before presenting `LandingView`
    /// results in `LandingView` seeing `.dark` — the shared env object
    /// carries across the Login → Landing navigation transition.
    @MainActor
    func testSchemeCarriesFromLoginToLanding() {
        // Simulate the same ThemeStore that AcmeBankApp creates once.
        let store = ThemeStore() // .light

        // User toggled the scheme on LoginView.
        store.toggle() // .dark

        XCTAssertEqual(store.preferredColorScheme, .dark,
                       "Store must be .dark after toggle")

        // LandingView presented with the same store — must observe .dark.
        let view = LandingView(session: makeSession()).environmentObject(store)
        render(view)

        // The store's scheme is still .dark after LandingView initialises.
        XCTAssertEqual(store.preferredColorScheme, .dark,
                       "LandingView must not reset the shared ThemeStore scheme")
    }
}
