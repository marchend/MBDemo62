import XCTest
@testable import AcmeBank

/// Unit tests for `KeychainStore`.
///
/// These tests never touch the real keychain — they inject a stub
/// `SecItemAPI` that simulates the subset of `SecItem*` behaviour the
/// store relies on: a duplicate `add` returns `errSecDuplicateItem`,
/// `copyMatching` returns the stored data, `update` overwrites, and
/// `delete` removes the entry.
///
/// `AuthServiceTests` also reaches into `KeychainStoreTests.StubKeychain`
/// to fabricate an in-memory `KeychainStore`, so the nested stub must
/// stay `internal` (the default) and keep its `makeAPI()` signature.
final class KeychainStoreTests: XCTestCase {

    // MARK: – Stub SecItemAPI

    /// In-memory stand-in for the global `SecItem*` C functions.
    ///
    /// Keyed by the `kSecAttrAccount` value from each query (i.e.
    /// `KeychainStore.Key.rawValue`).  Thread-unsafe by design — the
    /// tests are synchronous on the test queue.
    final class StubKeychain {

        /// account → stored Data
        private var storage: [String: Data] = [:]

        /// Pull the `kSecAttrAccount` value out of an opaque CFDictionary
        /// query.  Returns `""` if absent so a malformed query simply
        /// misses every lookup rather than crashing the test bundle.
        private static func account(from query: CFDictionary) -> String {
            let dict = query as NSDictionary
            return (dict[kSecAttrAccount as String] as? String) ?? ""
        }

        /// Build a `KeychainStore.SecItemAPI` whose four closures
        /// capture `self` so all calls share the same in-memory dict.
        func makeAPI() -> KeychainStore.SecItemAPI {
            KeychainStore.SecItemAPI(
                add: { [unowned self] query, _ in
                    let dict    = query as NSDictionary
                    let account = Self.account(from: query)
                    guard self.storage[account] == nil else {
                        return errSecDuplicateItem
                    }
                    guard let data = dict[kSecValueData as String] as? Data else {
                        return errSecParam
                    }
                    self.storage[account] = data
                    return errSecSuccess
                },
                copyMatching: { [unowned self] query, result in
                    let account = Self.account(from: query)
                    guard let data = self.storage[account] else {
                        return errSecItemNotFound
                    }
                    result?.pointee = data as CFTypeRef
                    return errSecSuccess
                },
                update: { [unowned self] query, attributes in
                    let account = Self.account(from: query)
                    guard self.storage[account] != nil else {
                        return errSecItemNotFound
                    }
                    let attrs = attributes as NSDictionary
                    guard let data = attrs[kSecValueData as String] as? Data else {
                        return errSecParam
                    }
                    self.storage[account] = data
                    return errSecSuccess
                },
                delete: { [unowned self] query in
                    let account = Self.account(from: query)
                    self.storage.removeValue(forKey: account)
                    return errSecSuccess
                }
            )
        }
    }

    // MARK: – Tests

    func testSaveThenRead_roundTripsValue() throws {
        let stub = StubKeychain()
        let store = KeychainStore(api: stub.makeAPI())

        try store.save("ACCESS-1", for: .accessToken)

        XCTAssertEqual(store.read(.accessToken), "ACCESS-1")
    }

    func testSaveTwice_overwritesPreviousValue() throws {
        let stub = StubKeychain()
        let store = KeychainStore(api: stub.makeAPI())

        try store.save("FIRST",  for: .idToken)
        try store.save("SECOND", for: .idToken)

        XCTAssertEqual(store.read(.idToken), "SECOND",
                       "second save must overwrite via the duplicate→update path")
    }

    func testReadMissingKey_returnsNil() {
        let stub = StubKeychain()
        let store = KeychainStore(api: stub.makeAPI())

        XCTAssertNil(store.read(.refreshToken))
    }

    func testDelete_removesStoredValue() throws {
        let stub = StubKeychain()
        let store = KeychainStore(api: stub.makeAPI())

        try store.save("REFRESH", for: .refreshToken)
        XCTAssertEqual(store.read(.refreshToken), "REFRESH")

        store.delete(.refreshToken)
        XCTAssertNil(store.read(.refreshToken))
    }

    func testDeleteMissingKey_isNoOp() {
        let stub = StubKeychain()
        let store = KeychainStore(api: stub.makeAPI())

        // Must not throw or crash.
        store.delete(.refreshToken)
        XCTAssertNil(store.read(.refreshToken))
    }

    func testKeysAreIsolated() throws {
        let stub = StubKeychain()
        let store = KeychainStore(api: stub.makeAPI())

        try store.save("ID",      for: .idToken)
        try store.save("ACCESS",  for: .accessToken)
        try store.save("REFRESH", for: .refreshToken)

        XCTAssertEqual(store.read(.idToken),      "ID")
        XCTAssertEqual(store.read(.accessToken),  "ACCESS")
        XCTAssertEqual(store.read(.refreshToken), "REFRESH")

        store.delete(.accessToken)

        XCTAssertEqual(store.read(.idToken),      "ID")
        XCTAssertNil(store.read(.accessToken))
        XCTAssertEqual(store.read(.refreshToken), "REFRESH")
    }

    func testBaseQuery_alwaysSetsDataProtectionKeychain() {
        // Defence-in-depth: the production invariant is that every
        // SecItem* call carries kSecUseDataProtectionKeychain=true.
        // Verify it directly on the query builder.
        let store = KeychainStore(api: StubKeychain().makeAPI())
        for key in KeychainStore.Key.allCases {
            let query = store.baseQuery(for: key)
            XCTAssertEqual(
                query[kSecUseDataProtectionKeychain as String] as? Bool,
                true,
                "kSecUseDataProtectionKeychain must be set for \(key.rawValue)"
            )
            XCTAssertEqual(query[kSecAttrAccount as String] as? String, key.rawValue)
        }
    }
}
