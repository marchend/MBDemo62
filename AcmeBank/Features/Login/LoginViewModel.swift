import Combine
import Foundation

// MARK: – AuthService seam

/// Protocol seam over `AuthService` so `LoginViewModel` can be unit-tested
/// without instantiating the real Okta-backed service.
///
/// Declared here (not in `AuthService.swift`) so PR 2's file remains
/// untouched by PR 3 — keeps the two PRs file-disjoint per the plan.
protocol AuthServiceProtocol {
    func signIn(
        username: String,
        password: String,
        keepSignedIn: Bool
    ) async throws -> UserSession
}

/// Conform the real `AuthService` to the protocol with a one-line
/// retroactive conformance.  No behavioural change.
extension AuthService: AuthServiceProtocol {}

// MARK: – LoginViewModel

/// ViewModel for the Login screen.
///
/// Holds UI state, drives the spinner / error banner, and routes the
/// on-screen credentials through `AuthServiceProtocol`.  The composition
/// root (PR 4) observes `session` to navigate away from Login on
/// success.
@MainActor
final class LoginViewModel: ObservableObject {

    // MARK: – Published state

    @Published var username: String = ""
    @Published var password: String = ""
    @Published var keepSignedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    /// Populated on a successful sign-in.  The composition root in PR 4
    /// observes this to navigate from Login to the post-auth landing.
    @Published var session: UserSession? = nil

    // MARK: – Dependencies

    private let authService: AuthServiceProtocol

    /// Combine subscriptions clearing `errorMessage` on edit.
    private var cancellables: Set<AnyCancellable> = []

    // MARK: – Init

    /// - Parameter authService: protocol-typed dependency.  Defaults to
    ///   a real `AuthService()`; tests inject a stub.
    init(authService: AuthServiceProtocol = AuthService()) {
        self.authService = authService

        // Clear any stale error the moment the user edits either field.
        // `dropFirst()` skips the initial value publication on subscribe
        // so we don't immediately overwrite an error set in the same
        // run loop tick.
        $username
            .dropFirst()
            .sink { [weak self] _ in self?.errorMessage = nil }
            .store(in: &cancellables)

        $password
            .dropFirst()
            .sink { [weak self] _ in self?.errorMessage = nil }
            .store(in: &cancellables)
    }

    // MARK: – Actions

    /// Call when the user taps the Sign In button.
    ///
    /// - Empty username/password → set the generic invalid-credentials
    ///   copy without touching `AuthService` (avoids a guaranteed-fail
    ///   network round-trip).
    /// - Otherwise drives `isLoading` true→false around an
    ///   `authService.signIn` call and maps each `AuthError` case to
    ///   the exact user-facing copy from the story.
    /// - Re-entrant calls while `isLoading == true` are ignored
    ///   (debounces a double-tap on Sign In).
    func submitSignIn() {
        // Debounce: a double-tap on the button must not produce two
        // concurrent AuthService calls.
        guard !isLoading else { return }

        // Cheap client-side guard — don't burn an Okta round-trip on
        // an obviously-empty form.
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Incorrect username or password. Please try again."
            return
        }

        isLoading = true
        errorMessage = nil

        let username = self.username
        let password = self.password
        let keepSignedIn = self.keepSignedIn

        Task { [weak self] in
            guard let self else { return }
            defer { self.isLoading = false }
            do {
                let session = try await self.authService.signIn(
                    username:     username,
                    password:     password,
                    keepSignedIn: keepSignedIn
                )
                self.session = session
            } catch let error as AuthError {
                self.errorMessage = Self.message(for: error)
            } catch {
                // Anything not surfaced as a typed `AuthError` is
                // reported as a generic transport failure — keeps the
                // banner copy stable for unknown SDK errors.
                self.errorMessage = "Couldn't reach Okta — check your connection and try again."
            }
        }
    }

    // MARK: – Error-to-copy mapping

    /// Maps each typed `AuthError` to the exact user-facing string
    /// prescribed by the story.  Centralised so the test suite can
    /// assert verbatim equality without scattering the copy across
    /// multiple call sites.
    private static func message(for error: AuthError) -> String {
        switch error {
        case .invalidCredentials:
            return "Incorrect username or password. Please try again."
        case .network:
            return "Couldn't reach Okta — check your connection and try again."
        case .mfaUnsupported:
            return "MFA is required but not supported in this build."
        case .notConfigured(let reason):
            return reason
        }
    }
}
