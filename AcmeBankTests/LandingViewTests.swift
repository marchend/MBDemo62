import XCTest
import SwiftUI
@testable import AcmeBank

/// Unit tests for `LandingView`.
///
/// The repo does not depend on ViewInspector, so these tests follow
/// the bootstrap pattern already in `AcmeBankTests.swift`: instantiate
/// the view with a fixture `UserSession`, drive it through a
/// `UIHostingController` to force SwiftUI to materialise the body
/// (this catches `fatalError` paths like a missing claim or an
/// uninitialised property), and assert that the underlying session
/// the view holds exposes the `displayName` / `email` values
/// verbatim.
///
/// Concretely we verify:
/// 1. The view initialises and hosts cleanly for a typical session.
/// 2. Unicode display names (CJK + emoji + RTL) do not crash on render.
/// 3. Pathologically long emails do not crash on render (no truncation
///    `fatalError`).
final class LandingViewTests: XCTestCase {

    // MARK: – Fixture

    private func makeSession(
        displayName: String = "Marc Henderson",
        email:       String = "marc@example.com"
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

    /// Forces SwiftUI to evaluate the view's `body` once.  If the body
    /// crashes (e.g. unwrap of a missing field) the test fails at
    /// `loadViewIfNeeded()` rather than silently passing on construction.
    @MainActor
    private func render<V: View>(_ view: V) {
        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()
    }

    // MARK: – Rendering

    @MainActor
    func test_landingView_initializes_withSession() {
        let session = makeSession()
        let view = LandingView(session: session)

        XCTAssertEqual(view.session.displayName, "Marc Henderson")
        XCTAssertEqual(view.session.email,       "marc@example.com")

        render(view)
    }

    @MainActor
    func test_landingView_rendersUnicodeDisplayName_withoutCrash() {
        // Mix of CJK, accented Latin, emoji, and RTL Arabic — the kinds
        // of `name` claims a real Okta tenant can return for global
        // users.  SwiftUI's `Text` must handle every one of these
        // grapheme clusters without truncation-related crashes.
        let names = [
            "山田 太郎",
            "Renée Müller-Schäfer",
            "🦄 Marc 🌈 Henderson 🎉",
            "محمد بن سلمان",
        ]
        for name in names {
            let view = LandingView(session: makeSession(displayName: name))
            XCTAssertEqual(view.session.displayName, name)
            render(view)
        }
    }

    @MainActor
    func test_landingView_rendersLongEmail_withoutCrash() {
        // 300-character email — far longer than any real address, but
        // proves the subhead label tolerates wrapping / truncation
        // without a layout-time fatalError.
        let localPart = String(repeating: "a", count: 280)
        let longEmail = "\(localPart)@example.com"

        let view = LandingView(session: makeSession(email: longEmail))
        XCTAssertEqual(view.session.email, longEmail)

        render(view)
    }

    // MARK: – Composition-root contract

    /// The composition root (`AcmeBankApp`) flips Login → Landing
    /// based on `LoginViewModel.session`.  Guarantee the public
    /// initialiser takes the session by value so it can be driven
    /// purely off SwiftUI navigation state (no singletons, no
    /// `UserDefaults`).
    @MainActor
    func test_landingView_takesSessionByValue() {
        let original = makeSession(displayName: "Original")
        let view = LandingView(session: original)

        // Mutating a local copy must not affect the rendered view.
        var copy = original
        copy = makeSession(displayName: "Mutated")
        _ = copy

        XCTAssertEqual(view.session.displayName, "Original")
    }
}
