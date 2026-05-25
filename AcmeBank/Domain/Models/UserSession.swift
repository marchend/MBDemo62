import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// In-memory snapshot of an authenticated user.
///
/// Populated by `AuthService.signIn` from the ID-token claims plus the
/// access token returned by Okta's `/oauth2/v1/token` endpoint.  The
/// **refresh token is intentionally NOT a field** — it lives in the
/// Keychain only (so it survives app restarts but never leaks into
/// logs, state restoration, or memory dumps that snapshot this struct).
///
/// `Codable` so future PRs can persist a non-secret subset (e.g. last
/// signed-in user banner) without pulling in another model type.
public struct UserSession: Codable, Equatable {

    /// Stable user identifier — the `sub` claim of the ID token.
    public let userId: String

    /// Human-friendly display name — the `name` claim of the ID token.
    public let displayName: String

    /// User email — the `email` claim of the ID token.
    public let email: String

    /// Bearer access token used on outbound API requests.  Short-lived;
    /// `RequestInterceptor` (future PR) refreshes it via the Keychain-
    /// resident refresh token.
    public let accessToken: String

    /// When the upstream IdP last authenticated the user.  Taken from
    /// the `auth_time` claim when present, otherwise the moment the
    /// `UserSession` was constructed.
    public let authTimestamp: Date

    /// Friendly device name — `UIDevice.current.name` at sign-in time
    /// (e.g. "Marc's iPhone").  Surfaced on the "trusted devices"
    /// screen and in security emails.
    public let deviceName: String

    public init(
        userId: String,
        displayName: String,
        email: String,
        accessToken: String,
        authTimestamp: Date,
        deviceName: String
    ) {
        self.userId        = userId
        self.displayName   = displayName
        self.email         = email
        self.accessToken   = accessToken
        self.authTimestamp = authTimestamp
        self.deviceName    = deviceName
    }

    // MARK: – JWT decoding

    /// Errors thrown while decoding the ID-token JWT payload.
    public enum DecodeError: Error, Equatable {
        /// JWT did not have three dot-separated segments.
        case malformedJWT
        /// Middle segment failed base64-url decoding.
        case invalidBase64
        /// Decoded payload was not a JSON object with the required
        /// string claims (`sub`, `name`, `email`).
        case missingClaim(String)
    }

    /// Decode the ID-token JWT payload (no signature verification —
    /// the SDK has already validated it) and project the claims onto a
    /// `UserSession`.
    ///
    /// - Parameters:
    ///   - idToken: dotted JWT string produced by Okta.
    ///   - accessToken: bearer token to embed on the session.
    /// - Returns: populated `UserSession`.
    /// - Throws: ``DecodeError`` if the JWT is malformed or required
    ///   claims (`sub`, `name`, `email`) are absent.
    public static func fromIDToken(
        _ idToken: String,
        accessToken: String
    ) throws -> UserSession {
        let segments = idToken.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else {
            throw DecodeError.malformedJWT
        }
        guard let payloadData = base64URLDecode(String(segments[1])) else {
            throw DecodeError.invalidBase64
        }
        guard
            let json = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        else {
            throw DecodeError.missingClaim("payload")
        }
        guard let sub   = json["sub"]   as? String else { throw DecodeError.missingClaim("sub")   }
        guard let name  = json["name"]  as? String else { throw DecodeError.missingClaim("name")  }
        guard let email = json["email"] as? String else { throw DecodeError.missingClaim("email") }

        // `auth_time` is OPTIONAL per the OIDC core spec.  Fall back to
        // "now" so a stripped-down IdP still produces a usable session.
        let authTimestamp: Date
        if let authTime = json["auth_time"] as? TimeInterval {
            authTimestamp = Date(timeIntervalSince1970: authTime)
        } else if let authTimeInt = json["auth_time"] as? Int {
            authTimestamp = Date(timeIntervalSince1970: TimeInterval(authTimeInt))
        } else {
            authTimestamp = Date()
        }

        return UserSession(
            userId:        sub,
            displayName:   name,
            email:         email,
            accessToken:   accessToken,
            authTimestamp: authTimestamp,
            deviceName:    currentDeviceName()
        )
    }

    // MARK: – Helpers

    /// Base64-URL decoder per RFC 7515 §2: `-` → `+`, `_` → `/`, and
    /// pad with `=` to a multiple of 4 before standard base64 decoding.
    private static func base64URLDecode(_ input: String) -> Data? {
        var s = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = (4 - s.count % 4) % 4
        s.append(String(repeating: "=", count: pad))
        return Data(base64Encoded: s)
    }

    /// `UIDevice.current.name` when UIKit is available; a stable
    /// placeholder otherwise (e.g. host-side unit-test runs on macOS
    /// without UIKit, though our XCTest target does import UIKit).
    private static func currentDeviceName() -> String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return "Unknown Device"
        #endif
    }
}
