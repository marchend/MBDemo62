import XCTest
@testable import AcmeBank

final class OktaConfigTests: XCTestCase {

    // MARK: – Fixtures

    /// Build a complete, valid info-dictionary; tests override single
    /// keys to drive each branch.
    private func makeInfo(
        issuer: Any? = "https://example.okta.com/oauth2/default",
        clientID: Any? = "0oaCLIENT123",
        redirectURI: Any? = "com.acmebank.mobile:/callback",
        scopes: Any? = "openid profile offline_access"
    ) -> [String: Any] {
        var dict: [String: Any] = [:]
        if let issuer      { dict["OktaIssuer"]      = issuer }
        if let clientID    { dict["OktaClientID"]    = clientID }
        if let redirectURI { dict["OktaRedirectURI"] = redirectURI }
        if let scopes      { dict["OktaScopes"]      = scopes }
        return dict
    }

    // MARK: – (a) Happy path

    func testLoad_allValuesPresent_returnsConfigured() {
        let info = makeInfo()

        let result = OktaConfig.load(from: info)

        guard case let .configured(issuer, clientID, redirectURI, scopes) = result else {
            return XCTFail("expected .configured, got \(result)")
        }
        XCTAssertEqual(issuer.absoluteString,      "https://example.okta.com/oauth2/default")
        XCTAssertEqual(clientID,                   "0oaCLIENT123")
        XCTAssertEqual(redirectURI.absoluteString, "com.acmebank.mobile:/callback")
        XCTAssertEqual(scopes, ["openid", "profile", "offline_access"])
    }

    func testLoad_scopesSplitOnCommas() {
        let info = makeInfo(scopes: "openid,profile,offline_access")

        guard case let .configured(_, _, _, scopes) = OktaConfig.load(from: info) else {
            return XCTFail("expected .configured")
        }
        XCTAssertEqual(scopes, ["openid", "profile", "offline_access"])
    }

    func testLoad_scopesSplitOnMixedWhitespaceAndCommas() {
        let info = makeInfo(scopes: "openid, profile,   offline_access")

        guard case let .configured(_, _, _, scopes) = OktaConfig.load(from: info) else {
            return XCTFail("expected .configured")
        }
        XCTAssertEqual(scopes, ["openid", "profile", "offline_access"])
    }

    // MARK: – (b) Sentinel detection

    func testLoad_issuerIsSentinel_returnsNotConfigured() {
        let info = makeInfo(issuer: "OKTA_NOT_CONFIGURED")

        let result = OktaConfig.load(from: info)

        XCTAssertEqual(result, .notConfigured(reason: OktaConfig.notConfiguredReason))
    }

    func testLoad_clientIDIsSentinel_returnsNotConfigured() {
        let info = makeInfo(clientID: "OKTA_NOT_CONFIGURED")

        let result = OktaConfig.load(from: info)

        XCTAssertEqual(result, .notConfigured(reason: OktaConfig.notConfiguredReason))
    }

    func testLoad_redirectURIIsSentinel_returnsNotConfigured() {
        let info = makeInfo(redirectURI: "OKTA_NOT_CONFIGURED")

        let result = OktaConfig.load(from: info)

        XCTAssertEqual(result, .notConfigured(reason: OktaConfig.notConfiguredReason))
    }

    func testLoad_scopesIsSentinel_returnsNotConfigured() {
        let info = makeInfo(scopes: "OKTA_NOT_CONFIGURED")

        let result = OktaConfig.load(from: info)

        XCTAssertEqual(result, .notConfigured(reason: OktaConfig.notConfiguredReason))
    }

    func testLoad_notConfigured_reasonStringIsStable() {
        let info = makeInfo(issuer: "OKTA_NOT_CONFIGURED")

        guard case let .notConfigured(reason) = OktaConfig.load(from: info) else {
            return XCTFail("expected .notConfigured")
        }
        XCTAssertEqual(reason, "Okta is not configured on this build — see README.")
    }

    // MARK: – (c) Missing key entirely

    func testLoad_missingIssuer_returnsNotConfigured() {
        let info = makeInfo(issuer: nil)

        XCTAssertEqual(
            OktaConfig.load(from: info),
            .notConfigured(reason: OktaConfig.notConfiguredReason)
        )
    }

    func testLoad_missingClientID_returnsNotConfigured() {
        let info = makeInfo(clientID: nil)

        XCTAssertEqual(
            OktaConfig.load(from: info),
            .notConfigured(reason: OktaConfig.notConfiguredReason)
        )
    }

    func testLoad_missingRedirectURI_returnsNotConfigured() {
        let info = makeInfo(redirectURI: nil)

        XCTAssertEqual(
            OktaConfig.load(from: info),
            .notConfigured(reason: OktaConfig.notConfiguredReason)
        )
    }

    func testLoad_missingScopes_returnsNotConfigured() {
        let info = makeInfo(scopes: nil)

        XCTAssertEqual(
            OktaConfig.load(from: info),
            .notConfigured(reason: OktaConfig.notConfiguredReason)
        )
    }

    func testLoad_emptyDictionary_returnsNotConfigured() {
        XCTAssertEqual(
            OktaConfig.load(from: [:]),
            .notConfigured(reason: OktaConfig.notConfiguredReason)
        )
    }

    func testLoad_whitespaceOnlyValue_treatedAsMissing() {
        let info = makeInfo(clientID: "   \n\t  ")

        XCTAssertEqual(
            OktaConfig.load(from: info),
            .notConfigured(reason: OktaConfig.notConfiguredReason)
        )
    }

    // MARK: – (d) Malformed URL — must NOT crash

    func testLoad_malformedIssuerURL_returnsNotConfigured() {
        // No scheme + no host → not a valid absolute URL for OIDC.
        let info = makeInfo(issuer: "not a url at all")

        let result = OktaConfig.load(from: info)

        // The contract is "no crash, returns .notConfigured".
        XCTAssertEqual(result, .notConfigured(reason: OktaConfig.notConfiguredReason))
    }

    func testLoad_issuerMissingScheme_returnsNotConfigured() {
        let info = makeInfo(issuer: "example.okta.com/oauth2/default")

        XCTAssertEqual(
            OktaConfig.load(from: info),
            .notConfigured(reason: OktaConfig.notConfiguredReason)
        )
    }

    func testLoad_redirectURIMissingScheme_returnsNotConfigured() {
        let info = makeInfo(redirectURI: "   ")

        // Whitespace-only is treated as missing — covered by the
        // nonEmptyString helper.
        XCTAssertEqual(
            OktaConfig.load(from: info),
            .notConfigured(reason: OktaConfig.notConfiguredReason)
        )
    }

    func testLoad_emptyScopesAfterSplit_returnsNotConfigured() {
        // Only separator characters → no scope tokens.
        let info = makeInfo(scopes: " , , , ")

        XCTAssertEqual(
            OktaConfig.load(from: info),
            .notConfigured(reason: OktaConfig.notConfiguredReason)
        )
    }
}
