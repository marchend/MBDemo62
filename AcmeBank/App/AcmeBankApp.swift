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
@main
struct AcmeBankApp: App {

    /// Single source of truth for auth state.  `@StateObject` so the
    /// view model is created exactly once and outlives any structural
    /// change to the view tree.
    @StateObject private var loginVM = LoginViewModel()

    var body: some Scene {
        WindowGroup {
            if let session = loginVM.session {
                LandingView(session: session)
            } else {
                LoginView(viewModel: loginVM)
            }
        }
    }
}
