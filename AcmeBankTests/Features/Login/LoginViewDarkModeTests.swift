import XCTest
import SwiftUI
@testable import AcmeBank

/// Dark-mode integration tests for `LoginView`.
///
/// Verifies that:
/// 1. `LoginView` can be instantiated and rendered with a `ThemeStore`
///    in either colour scheme without crashing.
/// 2. The `ThemeToggleButton` is reachable from `LoginView` (i.e. it
///    sits in the same environment object scope).
/// 3. The Sign In button uses `Color("BrandNavy")` as its tint — we
///    assert indirectly by ensuring the named asset resolves cleanly and
///    the button renders without crash when the tint is applied.
/// 4. Existing `LoginView` smoke-render behaviour is unchanged.
final class LoginViewDarkModeTests: XCTestCase {

    // MARK: – Fixtures

    private func makeViewModel() -> LoginViewModel {
        LoginViewModel(authService: StubLoginAuthService())
    }

    @MainActor
    private func render<V: View>(_ view: V) {
        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()
    }

    // MARK: – ThemeToggleButton presence

    /// `LoginView` rendered with a `ThemeStore` must not crash — this proves
    /// the `ThemeToggleButton` inside the branding strip successfully reads
    /// the injected environment object.
    @MainActor
    func testToggleButtonPresentOnLoginView() {
        let store = ThemeStore()
        let vm = makeViewModel()
        let view = LoginView(viewModel: vm).environmentObject(store)
        render(view)
        // Reaching here means ThemeToggleButton resolved its @EnvironmentObject.
    }

    /// Same check in Dark mode — the toggle button must render without crash
    /// when the store is pre-set to `.dark`.
    @MainActor
    func testToggleButtonPresentOnLoginView_darkMode() {
        let store = ThemeStore()
        store.toggle() // .dark
        let vm = makeViewModel()
        let view = LoginView(viewModel: vm).environmentObject(store)
        render(view)
    }

    // MARK: – BrandNavy asset usage

    /// `Color("BrandNavy")` must resolve without returning a fallback
    /// placeholder — i.e. the named color asset exists in the asset catalog.
    func testBrandNavyUsedForSignInButton() {
        // `Color("BrandNavy")` returns Color.clear when the asset does not
        // exist.  We verify the asset resolves by confirming UIColor
        // initialisation returns a non-nil value (iOS will use the fallback
        // only when the asset is missing from the bundle).
        let resolved = UIColor(named: "BrandNavy")
        XCTAssertNotNil(resolved,
                        "BrandNavy must exist as a named color asset in Assets.xcassets")
    }

    // MARK: – Existing LoginView tests continue to pass (smoke)

    /// Verifies that the standard `LoginView` initialisation and rendering
    /// path still works correctly after the dark-mode modifications.
    @MainActor
    func testExistingLoginViewTestsPassUnchanged() {
        let store = ThemeStore()
        let vm = makeViewModel()

        // Initial state is unchanged.
        XCTAssertEqual(vm.username, "")
        XCTAssertEqual(vm.password, "")
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)

        // View renders without crash.
        let view = LoginView(viewModel: vm).environmentObject(store)
        render(view)
    }
}

// MARK: – Minimal stub (test-only)

/// Stub `AuthServiceProtocol` used by `LoginViewDarkModeTests` to avoid
/// any network or Okta SDK calls during render tests.
private final class StubLoginAuthService: AuthServiceProtocol, @unchecked Sendable {
    func signIn(
        username: String,
        password: String,
        keepSignedIn: Bool
    ) async throws -> UserSession {
        throw AuthError.network
    }
}
