import Foundation
import OktaDirectAuth

/// Errors surfaced by ``AuthService/signIn(username:password:keepSignedIn:)``.
///
/// These are intentionally coarse — they map onto Login-screen messages
/// and do not leak raw SDK / network details to the UI layer.
public enum AuthError: Error, Equatable {
    /// Okta rejected the username/password combination.
    case invalidCredentials
    /// A transient network / transport failure.
    case network
    /// Okta returned an MFA challenge.  This MVP does not yet
    /// implement the second-factor UI, so we surface a typed error
    /// instead of crashing or silently succeeding.
    case mfaUnsupported
    /// `OktaConfig.load()` returned `.notConfigured(reason:)`.
    /// The wrapped reason is the same string surfaced by `OktaConfig`.
    case notConfigured(String)
}

/// Outcome of one sign-in attempt against Okta DirectAuth, normalised
/// so tests can drive ``AuthService`` without depending on the Okta SDK
/// types.  Production code converts the SDK's
/// `DirectAuthenticationFlow.Status` into this enum (see
/// `LiveDirectAuthStarter` below).
enum DirectAuthOutcome {
    /// Tokens issued.  `refreshToken` is optional because Okta only
    /// returns one when the `offline_access` scope was requested.
    case success(idToken: String, accessToken: String, refreshToken: String?)
    /// Second-factor required — not yet supported by this app.
    case mfaRequired
}

/// Closure-typed seam that performs one DirectAuth round-trip.
/// Production wiring lives in `AuthService.makeLiveStarter(...)`;
/// `AuthServiceTests` injects a stub that returns canned outcomes or
/// throws synthetic errors.
typealias DirectAuthStarter = (_ username: String, _ password: String) async throws -> DirectAuthOutcome

/// The auth core.
///
/// `signIn` exchanges a username/password (+ a `keepSignedIn` flag)
/// for a populated ``UserSession``.  The refresh token is persisted
/// only when `keepSignedIn == true`; id + access tokens are persisted
/// unconditionally so the access token survives a brief background
/// suspend.
///
/// Composition root (PR 3) constructs `AuthService(keychain: ...)` —
/// the live `DirectAuthStarter` is built lazily from `OktaConfig` on
/// every call so a misconfigured build surfaces a typed
/// `.notConfigured` error rather than crashing at init.
public final class AuthService {

    private let keychain: KeychainStore
    private let configLoader: () -> OktaConfig
    private let starterFactory: (OktaConfig) -> DirectAuthStarter

    // MARK: – Init

    /// Production initialiser.  Reads `OktaConfig.load()` on every
    /// sign-in attempt and builds a fresh `DirectAuthenticationFlow`
    /// from the four configured values.
    public convenience init(keychain: KeychainStore = KeychainStore()) {
        self.init(
            keychain:       keychain,
            configLoader:   OktaConfig.load,
            starterFactory: AuthService.makeLiveStarter(for:)
        )
    }

    /// Test initialiser.  Lets `AuthServiceTests` swap the config and
    /// the DirectAuth flow without touching the SDK or the network.
    init(
        keychain: KeychainStore,
        configLoader: @escaping () -> OktaConfig,
        starterFactory: @escaping (OktaConfig) -> DirectAuthStarter
    ) {
        self.keychain       = keychain
        self.configLoader   = configLoader
        self.starterFactory = starterFactory
    }

    // MARK: – Sign in

    /// Run one DirectAuth sign-in.
    ///
    /// On `.success` we decode the ID token into a ``UserSession``,
    /// write the tokens to the Keychain (refresh token only if
    /// `keepSignedIn == true`), and return the session.
    public func signIn(
        username: String,
        password: String,
        keepSignedIn: Bool
    ) async throws -> UserSession {
        let config = configLoader()
        guard case .configured = config else {
            if case let .notConfigured(reason) = config {
                throw AuthError.notConfigured(reason)
            }
            throw AuthError.notConfigured(OktaConfig.notConfiguredReason)
        }

        let starter = starterFactory(config)
        let outcome: DirectAuthOutcome
        do {
            outcome = try await starter(username, password)
        } catch let error as AuthError {
            throw error
        } catch {
            throw mapTransportError(error)
        }

        switch outcome {
        case let .success(idToken, accessToken, refreshToken):
            let session = try UserSession.fromIDToken(idToken, accessToken: accessToken)

            // ID + access tokens are short-lived but always cached, so
            // a brief background suspend doesn't force a re-login.
            try keychain.save(idToken,     for: .idToken)
            try keychain.save(accessToken, for: .accessToken)

            // Refresh token is the only thing that lets us survive an
            // app kill, so it is the toggle for "Keep me signed in".
            if keepSignedIn, let refreshToken {
                try keychain.save(refreshToken, for: .refreshToken)
            } else {
                // Defensive: clear any stale refresh token left over
                // from a previous "keep me signed in" session so a
                // user who unticks the box really does sign out fully
                // on next app kill.
                keychain.delete(.refreshToken)
            }

            return session

        case .mfaRequired:
            throw AuthError.mfaUnsupported
        }
    }

    // MARK: – Error mapping

    /// Coerce an underlying SDK / URLSession error into one of our
    /// typed cases.  Anything that looks like a bad-credentials
    /// response collapses to `.invalidCredentials`; everything else
    /// is reported as `.network` so the UI can offer a generic retry.
    private func mapTransportError(_ error: Error) -> AuthError {
        let nsError = error as NSError
        // Okta's DirectAuth surfaces invalid_grant on a userInfo key
        // of its OAuth2Error; we also accept HTTP 401.
        let oauthError = (nsError.userInfo["error"] as? String)?.lowercased()
        if oauthError == "invalid_grant" || nsError.code == 401 {
            return .invalidCredentials
        }
        if nsError.domain == NSURLErrorDomain {
            return .network
        }
        return .network
    }

    // MARK: – Live DirectAuth wiring

    /// Build a closure that runs one real DirectAuth round-trip
    /// against the Okta tenant described by `config`.
    ///
    /// Per the OktaDirectAuth Expert Reference, `start` takes the
    /// username positionally and the factor as the `with:` argument
    /// — there is NO `.primary(...)` wrapper on `PrimaryFactor`
    /// (that wrapper does not exist on the type; trying to use it
    /// is the MD058-2 PR #3 regression we are explicitly avoiding).
    private static func makeLiveStarter(for config: OktaConfig) -> DirectAuthStarter {
        return { username, password in
            guard case let .configured(issuer, clientID, _, scopes) = config else {
                throw AuthError.notConfigured(OktaConfig.notConfiguredReason)
            }

            // OktaDirectAuth 2.x takes scopes as a single
            // space-separated string, matching what Okta admins paste
            // into env vars.
            let scopeString = scopes.joined(separator: " ")

            let flow = DirectAuthenticationFlow(
                issuer:   issuer,
                clientId: clientID,
                scopes:   scopeString
            )

            let status = try await flow.start(username, with: .password(password))

            switch status {
            case .success(let token):
                let idToken      = token.idToken?.rawValue ?? ""
                let accessToken  = token.accessToken
                let refreshToken = token.refreshToken
                return .success(
                    idToken:      idToken,
                    accessToken:  accessToken,
                    refreshToken: refreshToken
                )
            default:
                // Anything other than `.success` — `.mfaRequired`,
                // `.bindingUpdate`, `.continuation`, etc. — is an MFA
                // / step-up flow we do not yet implement.
                return .mfaRequired
            }
        }
    }
}
