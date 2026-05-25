import Foundation

/// ViewModel for the Login screen.
///
/// Holds UI state and delegates the actual sign-in action to an injected
/// closure so the screen can be unit-tested without any auth dependency.
final class LoginViewModel: ObservableObject {

    // MARK: – Published state

    @Published var username: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: – Dependencies

    /// Injected sign-in action.  Default no-op keeps Xcode Previews
    /// and unit-test construction simple.
    private let signIn: () -> Void

    // MARK: – Init

    init(signIn: @escaping () -> Void = {}) {
        self.signIn = signIn
    }

    // MARK: – Actions

    /// Call when the user taps the Sign In button.
    /// Sets `isLoading` to `true` and forwards to the injected closure.
    @MainActor
    func submitSignIn() {
        isLoading = true
        signIn()
    }
}
