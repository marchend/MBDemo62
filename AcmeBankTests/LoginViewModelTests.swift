import XCTest
import Combine
@testable import AcmeBank

/// Unit tests for `LoginViewModel`.
///
/// All tests inject a stub `AuthServiceProtocol` so they never
/// instantiate the real `AuthService` and never touch the network /
/// Okta SDK.
@MainActor
final class LoginViewModelTests: XCTestCase {

    // MARK: – Fixtures

    private func makeSession() -> UserSession {
        UserSession(
            userId:        "00uABC",
            displayName:   "Marc Henderson",
            email:         "marc@example.com",
            accessToken:   "ACCESS",
            authTimestamp: Date(timeIntervalSince1970: 1_700_000_000),
            deviceName:    "Test Device"
        )
    }

    /// Polls `condition` on the main actor until it returns true or
    /// `timeout` seconds elapse.  Used to await the `Task` that
    /// `submitSignIn` kicks off without baking sleep durations into
    /// the production code.
    private func waitUntil(
        timeout: TimeInterval = 2.0,
        _ condition: @MainActor () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 5_000_000) // 5 ms
        }
        XCTFail("Condition not met within \(timeout)s", file: file, line: line)
    }

    // MARK: – Initial state

    func testInitialState() {
        let vm = LoginViewModel(authService: StubAuthService())

        XCTAssertEqual(vm.username, "")
        XCTAssertEqual(vm.password, "")
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertNil(vm.session)
        XCTAssertFalse(vm.keepSignedIn)
    }

    // MARK: – Empty-field guard

    func testSubmitSignIn_emptyUsername_setsErrorAndSkipsAuthService() async {
        let stub = StubAuthService()
        let vm = LoginViewModel(authService: stub)
        vm.password = "secret"

        vm.submitSignIn()

        // Give any erroneously-scheduled Task a chance to run.
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(
            vm.errorMessage,
            "Incorrect username or password. Please try again."
        )
        XCTAssertEqual(stub.callCount, 0, "AuthService must not be called when username is empty")
        XCTAssertFalse(vm.isLoading)
    }

    func testSubmitSignIn_emptyPassword_setsErrorAndSkipsAuthService() async {
        let stub = StubAuthService()
        let vm = LoginViewModel(authService: stub)
        vm.username = "marc@example.com"

        vm.submitSignIn()

        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(
            vm.errorMessage,
            "Incorrect username or password. Please try again."
        )
        XCTAssertEqual(stub.callCount, 0)
    }

    // MARK: – Happy path

    func testSubmitSignIn_success_publishesSessionAndClearsLoading() async {
        let stub = StubAuthService()
        let session = makeSession()
        stub.outcome = .success(session)

        let vm = LoginViewModel(authService: stub)
        vm.username = "marc@example.com"
        vm.password = "secret"
        vm.keepSignedIn = true

        vm.submitSignIn()

        await waitUntil { vm.session != nil }

        XCTAssertEqual(vm.session, session)
        XCTAssertFalse(vm.isLoading, "isLoading must clear after success")
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(stub.callCount, 1)
        XCTAssertEqual(stub.lastUsername, "marc@example.com")
        XCTAssertEqual(stub.lastPassword, "secret")
        XCTAssertEqual(stub.lastKeepSignedIn, true)
    }

    func testSubmitSignIn_setsIsLoadingTrueDuringCall() async {
        let gate = AsyncGate()
        let gatedStub = GatedStubAuthService(gate: gate, onResume: makeSession())

        let vm = LoginViewModel(authService: gatedStub)
        vm.username = "marc@example.com"
        vm.password = "secret"

        vm.submitSignIn()

        // Wait for the Task to have entered AuthService.signIn.
        await waitUntil { gatedStub.didEnterCount > 0 }

        XCTAssertTrue(vm.isLoading, "isLoading must be true while AuthService.signIn is in-flight")

        // Release the gate to let signIn resolve.
        await gate.open()

        await waitUntil { !vm.isLoading }
        XCTAssertNotNil(vm.session)
    }

    // MARK: – Error → copy mapping

    func testSubmitSignIn_invalidCredentials_setsExactCopy() async {
        let stub = StubAuthService()
        stub.outcome = .failure(.invalidCredentials)

        let vm = LoginViewModel(authService: stub)
        vm.username = "marc"
        vm.password = "wrong"

        vm.submitSignIn()
        await waitUntil { vm.errorMessage != nil }

        XCTAssertEqual(
            vm.errorMessage,
            "Incorrect username or password. Please try again."
        )
        XCTAssertNil(vm.session)
        XCTAssertFalse(vm.isLoading)
    }

    func testSubmitSignIn_network_setsExactCopy() async {
        let stub = StubAuthService()
        stub.outcome = .failure(.network)

        let vm = LoginViewModel(authService: stub)
        vm.username = "marc"
        vm.password = "secret"

        vm.submitSignIn()
        await waitUntil { vm.errorMessage != nil }

        XCTAssertEqual(
            vm.errorMessage,
            "Couldn't reach Okta — check your connection and try again."
        )
    }

    func testSubmitSignIn_mfaUnsupported_setsExactCopy() async {
        let stub = StubAuthService()
        stub.outcome = .failure(.mfaUnsupported)

        let vm = LoginViewModel(authService: stub)
        vm.username = "marc"
        vm.password = "secret"

        vm.submitSignIn()
        await waitUntil { vm.errorMessage != nil }

        XCTAssertEqual(
            vm.errorMessage,
            "MFA is required but not supported in this build."
        )
    }

    func testSubmitSignIn_notConfigured_surfacesReasonVerbatim() async {
        let stub = StubAuthService()
        let reason = "Okta is not configured on this build — see README."
        stub.outcome = .failure(.notConfigured(reason))

        let vm = LoginViewModel(authService: stub)
        vm.username = "marc"
        vm.password = "secret"

        vm.submitSignIn()
        await waitUntil { vm.errorMessage != nil }

        XCTAssertEqual(vm.errorMessage, reason)
    }

    // MARK: – Editing clears stale error

    func testEditingUsername_clearsErrorMessage() async {
        let stub = StubAuthService()
        stub.outcome = .failure(.invalidCredentials)
        let vm = LoginViewModel(authService: stub)
        vm.username = "marc"
        vm.password = "wrong"
        vm.submitSignIn()
        await waitUntil { vm.errorMessage != nil }

        vm.username = "marcus"

        // Combine sink fires on the main run loop — yield once so the
        // subscription's closure has a chance to run.
        await Task.yield()
        XCTAssertNil(vm.errorMessage)
    }

    func testEditingPassword_clearsErrorMessage() async {
        let stub = StubAuthService()
        stub.outcome = .failure(.invalidCredentials)
        let vm = LoginViewModel(authService: stub)
        vm.username = "marc"
        vm.password = "wrong"
        vm.submitSignIn()
        await waitUntil { vm.errorMessage != nil }

        vm.password = "right"

        await Task.yield()
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: – Double-tap debounce

    func testSubmitSignIn_whileLoading_isIgnored() async {
        let gate = AsyncGate()
        let gatedStub = GatedStubAuthService(gate: gate, onResume: makeSession())

        let vm = LoginViewModel(authService: gatedStub)
        vm.username = "marc"
        vm.password = "secret"

        vm.submitSignIn()
        await waitUntil { gatedStub.didEnterCount > 0 }

        // Second + third taps while the first call is in-flight — must
        // be ignored (no second AuthService call).
        vm.submitSignIn()
        vm.submitSignIn()

        // Release the original call so the test can wind down.
        await gate.open()
        await waitUntil { !vm.isLoading }

        XCTAssertEqual(
            gatedStub.didEnterCount,
            1,
            "AuthService must be called exactly once despite three taps"
        )
    }
}

// MARK: – Stub AuthService (test-only)

/// In-process stand-in for `AuthServiceProtocol` that returns a canned
/// outcome on every call.  `nonisolated` so it satisfies the protocol's
/// non-MainActor `signIn` signature.
final class StubAuthService: AuthServiceProtocol, @unchecked Sendable {

    enum Outcome {
        case success(UserSession)
        case failure(AuthError)
    }

    var outcome: Outcome = .failure(.network)
    private(set) var callCount = 0
    private(set) var lastUsername: String?
    private(set) var lastPassword: String?
    private(set) var lastKeepSignedIn: Bool?

    func signIn(
        username: String,
        password: String,
        keepSignedIn: Bool
    ) async throws -> UserSession {
        callCount += 1
        lastUsername = username
        lastPassword = password
        lastKeepSignedIn = keepSignedIn

        switch outcome {
        case .success(let session):
            return session
        case .failure(let err):
            throw err
        }
    }
}

// MARK: – Async gating helpers (test-only)

/// One-shot async gate.  `wait()` suspends until `open()` is called.
/// Used to hold an `AuthService.signIn` call in-flight so a test can
/// inspect mid-flight state (e.g. `isLoading == true`) without races.
private actor AsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { cont in
            self.continuation = cont
        }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

/// `AuthServiceProtocol` stub that suspends inside `signIn` until the
/// provided `AsyncGate` is opened, then returns `onResume`.
private final class GatedStubAuthService: AuthServiceProtocol, @unchecked Sendable {

    let gate: AsyncGate
    let onResume: UserSession
    private(set) var didEnterCount = 0

    init(gate: AsyncGate, onResume: UserSession) {
        self.gate = gate
        self.onResume = onResume
    }

    func signIn(
        username: String,
        password: String,
        keepSignedIn: Bool
    ) async throws -> UserSession {
        didEnterCount += 1
        await gate.wait()
        return onResume
    }
}
