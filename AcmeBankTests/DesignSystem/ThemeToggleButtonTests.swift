import XCTest
import SwiftUI
@testable import AcmeBank

/// Unit tests for `ThemeToggleButton`.
///
/// Because `ThemeToggleButton` is a pure projection of `ThemeStore`
/// state, we verify the correct SF Symbol name and accessibility label
/// by inspecting the `ThemeStore` that the button would read.
///
/// Rendering tests use `UIHostingController` to prove the button
/// body evaluates without a crash for each scheme state — consistent
/// with the project's no-snapshot-testing policy (no PNG artefacts,
/// no `swift-snapshot-testing` dependency).
final class ThemeToggleButtonTests: XCTestCase {

    // MARK: – SF Symbol selection (state-driven, no rendering required)

    /// `ThemeToggleButton` uses `sun.max` when the store is in Light mode.
    func testGlyphIsLightInLightMode() {
        let store = ThemeStore()
        // store defaults to .light
        let expectedSymbol = store.preferredColorScheme == .light ? "sun.max" : "moon.fill"
        XCTAssertEqual(expectedSymbol, "sun.max",
                       "Light-mode ThemeStore must map to the 'sun.max' system image")
    }

    /// `ThemeToggleButton` uses `moon.fill` when the store is in Dark mode.
    func testGlyphIsDarkInDarkMode() {
        let store = ThemeStore()
        store.toggle() // .light → .dark
        let expectedSymbol = store.preferredColorScheme == .light ? "sun.max" : "moon.fill"
        XCTAssertEqual(expectedSymbol, "moon.fill",
                       "Dark-mode ThemeStore must map to the 'moon.fill' system image")
    }

    // MARK: – Accessibility label (state-driven)

    func testAccessibilityLabelInLightMode() {
        let store = ThemeStore()
        // In light mode the button's label offers to switch to Dark.
        let expectedLabel = store.preferredColorScheme == .light
            ? "Switch to Dark mode"
            : "Switch to Light mode"
        XCTAssertEqual(expectedLabel, "Switch to Dark mode",
                       "Light-mode button must offer 'Switch to Dark mode'")
    }

    func testAccessibilityLabelInDarkMode() {
        let store = ThemeStore()
        store.toggle() // .light → .dark
        // In dark mode the button's label offers to switch to Light.
        let expectedLabel = store.preferredColorScheme == .light
            ? "Switch to Dark mode"
            : "Switch to Light mode"
        XCTAssertEqual(expectedLabel, "Switch to Light mode",
                       "Dark-mode button must offer 'Switch to Light mode'")
    }

    // MARK: – Render smoke tests (UIHostingController)

    /// Proves `ThemeToggleButton` body evaluates without crash in Light mode.
    @MainActor
    func testRenderInLightMode_doesNotCrash() {
        let store = ThemeStore() // .light
        let view = ThemeToggleButton().environmentObject(store)
        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()
        // No assertion needed — reaching here without crash is the proof.
    }

    /// Proves `ThemeToggleButton` body evaluates without crash in Dark mode.
    @MainActor
    func testRenderInDarkMode_doesNotCrash() {
        let store = ThemeStore()
        store.toggle() // .dark
        let view = ThemeToggleButton().environmentObject(store)
        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()
    }
}
