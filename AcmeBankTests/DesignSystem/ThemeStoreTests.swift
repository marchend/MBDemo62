import XCTest
import SwiftUI
@testable import AcmeBank

/// Unit tests for `ThemeStore`.
///
/// Verifies the three core contracts:
/// 1. A freshly initialised store defaults to `.light`.
/// 2. A single `toggle()` flips to `.dark`.
/// 3. A double `toggle()` returns to `.light`.
final class ThemeStoreTests: XCTestCase {

    // MARK: – Default state

    func testDefaultSchemeIsLight() {
        let store = ThemeStore()
        XCTAssertEqual(store.preferredColorScheme, .light,
                       "ThemeStore must initialise with .light")
    }

    // MARK: – Toggle

    func testToggleFlipsToDark() {
        let store = ThemeStore()

        store.toggle()

        XCTAssertEqual(store.preferredColorScheme, .dark,
                       "One toggle() must flip .light → .dark")
    }

    func testDoubleToggleReturnsToLight() {
        let store = ThemeStore()

        store.toggle()
        store.toggle()

        XCTAssertEqual(store.preferredColorScheme, .light,
                       "Two toggle() calls must return to .light")
    }
}
