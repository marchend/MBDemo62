import SwiftUI

/// A reusable toolbar/overlay button that toggles the app-wide colour
/// scheme managed by `ThemeStore`.
///
/// Reads the shared `ThemeStore` from the SwiftUI environment — the
/// caller must have injected `.environmentObject(themeStore)` somewhere
/// above this view in the hierarchy (done by `AcmeBankApp`).
///
/// Renders:
/// - `sun.max` (light mode active) — tapping switches to Dark
/// - `moon.fill` (dark mode active) — tapping switches to Light
///
/// The hit target is at least 44 × 44 pt to satisfy HIG tap-target
/// guidelines and accessibility audits.
struct ThemeToggleButton: View {

    @EnvironmentObject var themeStore: ThemeStore

    var body: some View {
        Button {
            themeStore.toggle()
        } label: {
            Image(systemName: themeStore.preferredColorScheme == .light
                ? "sun.max"
                : "moon.fill")
                .imageScale(.large)
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(
            themeStore.preferredColorScheme == .light
                ? "Switch to Dark mode"
                : "Switch to Light mode"
        )
    }
}

// MARK: – Preview

private struct ThemeToggleButtonPreview: View {
    @StateObject private var lightStore = ThemeStore()
    @StateObject private var darkStore: ThemeStore = {
        let s = ThemeStore()
        s.toggle()
        return s
    }()

    var body: some View {
        HStack(spacing: 24) {
            ThemeToggleButton()
                .environmentObject(lightStore)

            ThemeToggleButton()
                .environmentObject(darkStore)
        }
        .padding()
    }
}

#Preview {
    ThemeToggleButtonPreview()
}
