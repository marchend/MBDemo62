import XCTest
@testable import AcmeBank

/// Unit tests for `AuthService`.
///
/// All tests inject a stub `DirectAuthStarter` so they NEVER hit the
/// network — the real Okta SDK is unused, which matches the
/// acceptance criterion "tests do NOT hit the real network".
final class AuthServiceTests: XCTestCase {

    // MARK: – Fixtures

    /// A minimal-but-valid base64-URL-encoded JWT payload string.
    /// `header.payload.signature` — only the middle segment is read.
    private func makeIDToken(
        sub: String = "00uABC123",
        name: String = "Marc Henderson",
        email: String = "marc@example.com",
        authTime: TimeInterval? = 1_700_000_000
    ) -> String {
        var payload: [String: Any] = ["sub": sub, "name": name, "email": email]
        if let authTime { payload["auth_time"] = authTime }
        let payloadData = try! JSONSerialization.data(withJSONObject: payload,
                                                     options: [.sortedKeys])
        let payloadB64 = payloadData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "header.\(payloadB64).sig"
    }

    /// Build an `AuthService` wired to a stub keychain and a closure
    /// that controls the DirectAuth round-trip.  `config` defaults to
    /// `.configured(...)` so the happy path is one line.
    private func makeService(
        config: OktaConfig = .configured(
            issuer:      URL(string: "https://example.okta.com")!,
            clientID:    "0oaCLIENT",
            redirectURI: URL(string: "com.acmebank.mobile:/callback")!,
            scopes:      ["openid", "profile", "offline_access"]
        ),
        starter: @escaping DirectAuthStarter
    ) -> (AuthService, KeychainStore, KeychainStoreTests.StubKeychain) {
        let stub = KeychainStoreTests.StubKeychain()
        let keychain = KeychainStore(api: stub.makeAPI())
        let service = AuthService(
            keychain:       keychain,
            configLoader:   { config },
            starterFactory: { _ in starter }
        )
        return (service, keychain, stub)
    }

    // MARK: – Success path

    func testSignIn_successWithKeepSignedInTrue_writesAllThreeTokens() async throws {
        let idToken = makeIDToken()
        let (service, keychain, _) = makeService(starter: { _, _ in
            .success(idToken: idToken, accessToken: "ACCESS", refreshToken: "REFRESH")
        })

        let session = try await service.signIn(
            username: "marc@example.com",
            password: "hunter2",
            keepSignedIn: true
        )

        XCTAssertEqual(session.userId,      "00uABC123")
        XCTAssertEqual(session.displayName, "Marc Henderson")
        XCTAssertEqual(session.email,       "marc@example.com")
        XCTAssertEqual(session.accessToken, "ACCESS")

        XCTAssertEqual(keychain.read(.idToken),      idToken)
        XCTAssertEqual(keychain.read(.accessToken),  "ACCESS")
        XCTAssertEqual(keychain.read(.refreshToken), "REFRESH")
    }

    func testSignIn_successWithKeepSignedInFalse_writesOnlyIDAndAccess() async throws {
        let idToken = makeIDToken()
        let (service, keychain, _) = makeService(starter: { _, _ in
            .success(idToken: idToken, accessToken: "ACCESS", refreshToken: "REFRESH")
        })

        _ = try await service.signIn(
            username: "marc@example.com",
            password: "hunter2",
            keepSignedIn: false
        )

        XCTAssertEqual(keychain.read(.idToken),     idToken)
        XCTAssertEqual(keychain.read(.accessToken), "ACCESS")
        XCTAssertNil(keychain.read(.refreshToken),
                     "refresh token must NOT be persisted when keepSignedIn=false")
    }

    func testSignIn_keepSignedInFalse_clearsStaleRefreshToken() async throws {
        // A previous "keep me signed in" session left a refresh token
        // behind.  Signing in again with the box unticked must wipe it.
        let stub = KeychainStoreTests.StubKeychain()
        let keychain = KeychainStore(api: stub.makeAPI())
        try keychain.save("STALE-REFRESH", for: .refreshToken)

        let service = AuthService(
            keychain: keychain,
            configLoader: {
                .configured(
                    issuer:      URL(string: "https://example.okta.com")!,
                    clientID:    "0oaCLIENT",
                    redirectURI: URL(string: "com.acmebank.mobile:/callback")!,
                    scopes:      ["openid"]
                )
            },
            starterFactory: { _ in
                { _, _ in
                    .success(idToken: self.makeIDToken(),
                             accessToken: "ACCESS",
                             refreshToken: "NEW-REFRESH")
                }
            }
        )

        _ = try await service.signIn(username: "u", password: "p", keepSignedIn: false)

        XCTAssertNil(keychain.read(.refreshToken),
                     "stale refresh token must be cleared on keepSignedIn=false sign-in")
    }

    // MARK: – MFA

    func testSignIn_mfaRequired_throwsMFAUnsupported() async {
        let (service, keychain, _) = makeService(starter: { _, _ in .mfaRequired })

        do {
            _ = try await service.signIn(username: "u", password: "p", keepSignedIn: true)
            XCTFail("expected AuthError.mfaUnsupported")
        } catch {
            XCTAssertEqual(error as? AuthError, .mfaUnsupported)
        }

        // No partial token write on the MFA path.
        XCTAssertNil(keychain.read(.idToken))
        XCTAssertNil(keychain.read(.accessToken))
        XCTAssertNil(keychain.read(.refreshToken))
    }

    // MARK: – Error mapping

    func testSignIn_invalidCredentials_mapsToInvalidCredentials() async {
        // Okta surfaces bad creds as `error: invalid_grant` on the
        // OAuth2Error's userInfo dictionary.
        let badCredsError = NSError(
            domain: "OktaDirectAuth",
            code: 400,
            userInfo: ["error": "invalid_grant"]
        )
        let (service, _, _) = makeService(starter: { _, _ in throw badCredsError })

        do {
            _ = try await service.signIn(username: "u", password: "bad", keepSignedIn: false)
            XCTFail("expected AuthError.invalidCredentials")
        } catch {
            XCTAssertEqual(error as? AuthError, .invalidCredentials)
        }
    }

    func testSignIn_http401_mapsToInvalidCredentials() async {
        let unauth = NSError(domain: "HTTP", code: 401, userInfo: [:])
        let (service, _, _) = makeService(starter: { _, _ in throw unauth })

        do {
            _ = try await service.signIn(username: "u", password: "p", keepSignedIn: false)
            XCTFail("expected AuthError.invalidCredentials")
        } catch {
            XCTAssertEqual(error as? AuthError, .invalidCredentials)
        }
    }

    func testSignIn_networkError_mapsToNetwork() async {
        let netError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [:]
        )
        let (service, _, _) = makeService(starter: { _, _ in throw netError })

        do {
            _ = try await service.signIn(username: "u", password: "p", keepSignedIn: false)
            XCTFail("expected AuthError.network")
        } catch {
            XCTAssertEqual(error as? AuthError, .network)
        }
    }

    func testSignIn_authErrorFromStarter_propagatesUnchanged() async {
        // If the starter itself throws a typed AuthError it must pass
        // through unchanged (don't double-map into .network).
        let (service, _, _) = makeService(starter: { _, _ in
            throw AuthError.mfaUnsupported
        })

        do {
            _ = try await service.signIn(username: "u", password: "p", keepSignedIn: false)
            XCTFail("expected AuthError.mfaUnsupported")
        } catch {
            XCTAssertEqual(error as? AuthError, .mfaUnsupported)
        }
    }

    // MARK: – OktaConfig propagation

    func testSignIn_notConfigured_propagatesAsAuthErrorNotConfigured() async {
        let (service, _, _) = makeService(
            config: .notConfigured(reason: OktaConfig.notConfiguredReason),
            starter: { _, _ in
                XCTFail("starter must not be invoked when Okta is not configured")
                return .mfaRequired
            }
        )

        do {
            _ = try await service.signIn(username: "u", password: "p", keepSignedIn: false)
            XCTFail("expected AuthError.notConfigured")
        } catch {
            XCTAssertEqual(
                error as? AuthError,
                .notConfigured(OktaConfig.notConfiguredReason)
            )
        }
    }

    // MARK: – Malformed token from server

    func testSignIn_successWithMalformedIDToken_throwsDecodeError() async {
        let (service, keychain, _) = makeService(starter: { _, _ in
            .success(idToken: "not-a-jwt", accessToken: "ACCESS", refreshToken: nil)
        })

        do {
            _ = try await service.signIn(username: "u", password: "p", keepSignedIn: true)
            XCTFail("expected UserSession.DecodeError.malformedJWT")
        } catch let error as UserSession.DecodeError {
            XCTAssertEqual(error, .malformedJWT)
        } catch {
            XCTFail("expected UserSession.DecodeError, got \(error)")
        }

        // No token writes when the ID token can't be decoded.
        XCTAssertNil(keychain.read(.idToken))
        XCTAssertNil(keychain.read(.accessToken))
    }

    // MARK: – Server returns no refresh token

    func testSignIn_successWithoutRefreshToken_keepSignedInTrue_doesNotPersistRefresh() async throws {
        let (service, keychain, _) = makeService(starter: { _, _ in
            .success(idToken: self.makeIDToken(), accessToken: "ACCESS", refreshToken: nil)
        })

        _ = try await service.signIn(username: "u", password: "p", keepSignedIn: true)

        XCTAssertNil(keychain.read(.refreshToken),
                     "no refresh token to persist when the server didn't return one")
        XCTAssertEqual(keychain.read(.accessToken), "ACCESS")
    }
}
