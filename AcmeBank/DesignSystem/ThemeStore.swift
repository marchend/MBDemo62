import SwiftUI

/// Shared observable store that owns the user's preferred colour scheme.
///
/// Held as a `@StateObject` on `AcmeBankApp` and propagated through the
/// entire view tree via `.environmentObject(themeStore)` so that every
/// screen can read and mutate the scheme without prop-drilling.
///
/// Usage:
/// ```swift
/// @EnvironmentObject var themeStore: ThemeStore
/// themeStore.toggle()          // flip Light ↔ Dark
/// themeStore.preferredColorScheme  // current scheme
/// ```
final class ThemeStore: ObservableObject {

    /// The colour scheme currently preferred by the user.
    ///
    /// Starts as `.light` — the system default.  Callers should apply
    /// this to the `WindowGroup` root via
    /// `.preferredColorScheme(themeStore.preferredColorScheme)`.
    @Published var preferredColorScheme: ColorScheme = .light

    /// Toggles between `.light` and `.dark`.
    func toggle() {
        preferredColorScheme = preferredColorScheme == .light ? .dark : .light
    }
}
