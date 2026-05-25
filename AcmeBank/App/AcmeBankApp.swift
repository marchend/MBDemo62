import SwiftUI

/// `@main` entry point and composition root.
///
/// Owns the single `LoginViewModel` instance for the app's lifetime
/// (so its `@Published` state survives view-tree rebuilds) and
/// switches the root view based on whether `session` has been
/// populated by a successful sign-in:
///
/// * `session == nil`  → `LoginView` (user must authenticate)
/// * `session != nil`  → `LandingView` (post-auth greeting)
///
/// The `UserSession` is threaded through SwiftUI navigation state
/// only — never via `UserDefaults`, a singleton, or `NotificationCenter`.
///
/// `ThemeStore` is created here so a single instance is shared across
/// the entire view tree via `.environmentObject`.  Toggling the scheme
/// on `LoginView` therefore carries through to `LandingView`.
@main
struct AcmeBankApp: App {

    /// Single source of truth for auth state.  `@StateObject` so the
    /// view model is created exactly once and outlives any structural
    /// change to the view tree.
    @StateObject private var loginVM = LoginViewModel()

    /// Shared colour-scheme preference.  Injected into the whole tree
    /// so `ThemeToggleButton` instances on any screen all observe and
    /// mutate the same state.
    @StateObject private var themeStore = ThemeStore()

    var body: some Scene {
        WindowGroup {
            RootView(loginVM: loginVM)
                .environmentObject(themeStore)
                .preferredColorScheme(themeStore.preferredColorScheme)
        }
    }
}

// MARK: – Root content switcher

/// Thin wrapper that switches between `LoginView` and `LandingView`
/// based on the auth state from `LoginViewModel`.
///
/// Extracted so that `AcmeBankApp.body` (which returns `some Scene`)
/// can cleanly apply View-level modifiers (`.environmentObject`,
/// `.preferredColorScheme`) on a single root view.
private struct RootView: View {
    @ObservedObject var loginVM: LoginViewModel

    var body: some View {
        if let session = loginVM.session {
            LandingView(session: session)
        } else {
            LoginView(viewModel: loginVM)
        }
    }
}
