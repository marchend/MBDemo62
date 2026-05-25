import Foundation

/// Runtime representation of the Okta tenant configuration that was baked
/// into `Info.plist` at build time by the "Inject Okta config" Run Script
/// build phase (see `project.yml`).
///
/// The build script writes either the real env-var values (`OKTA_ISSUER`,
/// `OKTA_CLIENT_ID`, `OKTA_REDIRECT_URI`, `OKTA_SCOPES`) or the sentinel
/// string `OKTA_NOT_CONFIGURED` for any env var that was unset at build
/// time.  We NEVER hard-fail the build when env vars are missing — the
/// app must still launch on a fresh checkout — so this type carries a
/// `.notConfigured(reason:)` case that callers handle gracefully (e.g.
/// disable the "Sign In with Okta" button, show a banner).
///
/// Read once at app start via ``OktaConfig/load()``.  All real-world
/// validation (URL parsing, scope splitting, sentinel detection) lives
/// here so the rest of the app does not have to repeat it.
public enum OktaConfig: Equatable {

    /// All four Info.plist values were present, non-sentinel, and parsed
    /// into well-formed URLs / scopes.
    case configured(issuer: URL, clientID: String, redirectURI: URL, scopes: [String])

    /// At least one value was missing, was the build-time sentinel
    /// `OKTA_NOT_CONFIGURED`, or failed to parse.  `reason` is suitable
    /// for logging; callers should not surface it verbatim to end users.
    case notConfigured(reason: String)

    // MARK: – Constants

    /// Build-script sentinel written into Info.plist whenever the
    /// corresponding `OKTA_*` env var was unset at build time.  Kept in
    /// sync with the `plutil -replace … "${OKTA_ISSUER:-OKTA_NOT_CONFIGURED}"`
    /// invocations in `project.yml`.
    static let sentinel = "OKTA_NOT_CONFIGURED"

    /// Public reason string surfaced when any required value is missing
    /// or sentinel.  Stable so tests can assert on it.
    static let notConfiguredReason = "Okta is not configured on this build — see README."

    // MARK: – Info.plist keys

    enum InfoKey {
        static let issuer      = "OktaIssuer"
        static let clientID    = "OktaClientID"
        static let redirectURI = "OktaRedirectURI"
        static let scopes      = "OktaScopes"
    }

    // MARK: – Loaders

    /// Production entry point.  Reads `Bundle.main.infoDictionary`.
    public static func load() -> OktaConfig {
        load(from: Bundle.main.infoDictionary ?? [:])
    }

    /// Test seam.  Pure function over a supplied info dictionary so
    /// `OktaConfigTests` can drive every branch without touching the
    /// real bundle.
    static func load(from info: [String: Any]) -> OktaConfig {
        guard
            let issuerRaw      = nonEmptyString(info[InfoKey.issuer]),
            let clientIDRaw    = nonEmptyString(info[InfoKey.clientID]),
            let redirectRaw    = nonEmptyString(info[InfoKey.redirectURI]),
            let scopesRaw      = nonEmptyString(info[InfoKey.scopes])
        else {
            return .notConfigured(reason: notConfiguredReason)
        }

        // Sentinel = treat as not configured, no matter which key carries it.
        if issuerRaw   == sentinel
            || clientIDRaw == sentinel
            || redirectRaw == sentinel
            || scopesRaw   == sentinel {
            return .notConfigured(reason: notConfiguredReason)
        }

        guard
            let issuerURL   = URL(string: issuerRaw),
            let scheme      = issuerURL.scheme, !scheme.isEmpty,
            issuerURL.host != nil
        else {
            return .notConfigured(reason: notConfiguredReason)
        }

        guard
            let redirectURL  = URL(string: redirectRaw),
            let redirectScheme = redirectURL.scheme, !redirectScheme.isEmpty
        else {
            return .notConfigured(reason: notConfiguredReason)
        }

        // Split on whitespace and commas; drop empties.  Matches the
        // ergonomic forms Okta admins paste into env vars:
        //   "openid profile offline_access"
        //   "openid,profile,offline_access"
        //   "openid, profile,   offline_access"
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ","))
        let scopes = scopesRaw
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }

        guard !scopes.isEmpty else {
            return .notConfigured(reason: notConfiguredReason)
        }

        return .configured(
            issuer:      issuerURL,
            clientID:    clientIDRaw,
            redirectURI: redirectURL,
            scopes:      scopes
        )
    }

    // MARK: – Helpers

    /// Coerce an `Any?` from Info.plist into a trimmed, non-empty
    /// `String`.  Anything else (nil, non-string, all-whitespace) is
    /// treated as absent.
    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let s = value as? String else { return nil }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
