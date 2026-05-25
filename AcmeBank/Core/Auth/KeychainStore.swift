import Foundation
import Security

/// Thin, testable wrapper around the iOS Keychain for short-string
/// secrets (Okta ID / access / refresh tokens).
///
/// ### Why every query carries `kSecUseDataProtectionKeychain: true`
///
/// On the **simulator** the default keychain is the legacy
/// "file-based" keychain that requires the app to be code-signed with
/// a provisioning profile that includes a keychain-access-group.  Our
/// CI build runs with `CODE_SIGNING_ALLOWED=NO` (see `project.yml`),
/// so every `SecItem*` call against the default keychain fails with
/// `errSecMissingEntitlement` (-34018).  Opting into the modern
/// **Data Protection Keychain** (the same one that ships on real
/// devices and macOS Catalyst) skips the entitlement check on the
/// simulator and Just Works.  Forgetting this single attribute on any
/// query made the previous attempt at this layer flake on CI.
///
/// All three operations therefore funnel through `baseQuery(for:)`
/// which always sets the attribute; callers cannot accidentally omit
/// it.
public final class KeychainStore {

    // MARK: – Typed keys

    /// Strongly-typed account names so callers cannot mistype a key
    /// or smuggle PII into the keychain.  The `rawValue` is the
    /// `kSecAttrAccount` value persisted on the item.
    public enum Key: String, CaseIterable {
        case idToken      = "idToken"
        case accessToken  = "accessToken"
        case refreshToken = "refreshToken"
    }

    /// Errors thrown by `save`.  `read` and `delete` swallow misses by
    /// design — a delete on a missing item is a no-op, and a read on a
    /// missing item returns `nil`.
    public enum KeychainError: Error, Equatable {
        case unhandled(OSStatus)
        case invalidData
    }

    /// Service identifier used as `kSecAttrService` on every item.
    /// Stable across builds so an app upgrade can read items written
    /// by the previous version.
    static let service = "com.acmebank.mobile"

    // MARK: – SecItem seam (test injection)

    /// Closure-typed seam over the global `SecItem*` C functions.
    /// Production wiring uses ``LiveSecItemAPI``; tests inject a stub
    /// that captures the query dictionary so we can assert the
    /// `kSecUseDataProtectionKeychain` invariant.
    struct SecItemAPI {
        var add:          (_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
        var copyMatching: (_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
        var update:       (_ query: CFDictionary, _ attributes: CFDictionary) -> OSStatus
        var delete:       (_ query: CFDictionary) -> OSStatus

        static let live = SecItemAPI(
            add:          SecItemAdd,
            copyMatching: SecItemCopyMatching,
            update:       SecItemUpdate,
            delete:       SecItemDelete
        )
    }

    private let api: SecItemAPI

    // MARK: – Init

    public convenience init() {
        self.init(api: .live)
    }

    init(api: SecItemAPI) {
        self.api = api
    }

    // MARK: – Public API

    /// Persist `value` for `key`.  Overwrites any existing item.
    public func save(_ value: String, for key: Key) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // First, try a plain add.  If something is already there,
        // update it instead — keychain `SecItemAdd` is NOT idempotent.
        var addQuery = baseQuery(for: key)
        addQuery[kSecValueData as String] = data

        let addStatus = api.add(addQuery as CFDictionary, nil)
        switch addStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let updateQuery = baseQuery(for: key)
            let attributes: [String: Any] = [kSecValueData as String: data]
            let updateStatus = api.update(updateQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandled(updateStatus)
            }
        default:
            throw KeychainError.unhandled(addStatus)
        }
    }

    /// Read the value for `key`, or `nil` if no item is stored.
    public func read(_ key: Key) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String]  = true
        query[kSecMatchLimit as String]  = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = api.copyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Delete the value for `key`.  A miss is a no-op (`errSecItemNotFound`).
    public func delete(_ key: Key) {
        let query = baseQuery(for: key)
        _ = api.delete(query as CFDictionary)
    }

    // MARK: – Query construction (THE invariant)

    /// Build the shared query dictionary for `key`.  Every keychain
    /// operation in this type goes through here so the
    /// `kSecUseDataProtectionKeychain` attribute can never be
    /// accidentally omitted.
    func baseQuery(for key: Key) -> [String: Any] {
        return [
            kSecClass as String:                     kSecClassGenericPassword,
            kSecAttrService as String:               Self.service,
            kSecAttrAccount as String:               key.rawValue,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }
}
