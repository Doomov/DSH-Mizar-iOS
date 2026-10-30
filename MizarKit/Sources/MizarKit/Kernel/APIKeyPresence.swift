//
//  APIKeyPresence.swift
//  MizarKit
//
//  "Has this phone configured a model provider yet?" -- answered without
//  booting the kernel.
//
//  The host list needs the answer to draw the red "No model configured" pill,
//  and it needs it every time the list opens. Asking the kernel would mean
//  evaluating the 53 KB bundle and loading every session first, for a boolean;
//  the keys themselves are already in the Keychain under the same account the
//  kernel writes, so the answer is one `SecItemCopyMatching` away.
//
//  The account every key is filed under is `mizar.kernel.apiKey.<provider>` --
//  the prefix comes from ``KeychainKernelKeyValueStore`` and both have to agree.
//  That is why the constant lives here, next to the filter, rather than being
//  spelled out at each call site.
//

import Foundation
#if canImport(Security)
import Security
#endif

public enum APIKeyPresence {
    /// The Keychain service every kernel secret lives in.
    public static let defaultService = "dsh-mizar"
    /// The account prefix the kernel's store adds to its keys.
    public static let defaultPrefix = "mizar.kernel."
    /// The key one provider's API key is stored under, before the prefix.
    public static let apiKeyKeyPrefix = "apiKey."

    /// The Keychain account for one provider's API key.
    public static func account(forProvider provider: String, prefix: String = defaultPrefix) -> String {
        prefix + apiKeyKeyPrefix + provider
    }

    /// Whether any account in `accounts` is a provider key with a value.
    ///
    /// Separate from the Keychain read so the rule can be tested: the unit suite
    /// runs without the Keychain, and an untestable boolean is how "configured"
    /// and "not configured" drift apart between the pill and the settings page.
    ///
    /// - Parameters:
    ///   - accounts: account name to stored bytes, as the Keychain returns them.
    ///   - prefix: the kernel's account prefix.
    /// - Returns: `true` when at least one provider has a non-blank key.
    public static func hasKey(
        accounts: [String: Data],
        prefix: String = defaultPrefix,
    ) -> Bool {
        let wanted = prefix + apiKeyKeyPrefix
        for (account, data) in accounts where account.hasPrefix(wanted) {
            guard !account.hasSuffix(apiKeyKeyPrefix) else { continue }
            let text = String(decoding: data, as: UTF8.self)
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        }
        return false
    }

    /// Whether the app's Keychain holds at least one provider key.
    ///
    /// Reads attributes and data for every item in the kernel's service in one
    /// query. Nothing prompts: these are this app's own items, written
    /// `AfterFirstUnlockThisDeviceOnly`.
    public static func hasConfiguredProvider(
        service: String = defaultService,
        prefix: String = defaultPrefix,
    ) -> Bool {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else {
            // `errSecItemNotFound` is the ordinary first-launch answer.
            return false
        }
        var accounts: [String: Data] = [:]
        for item in items {
            guard let account = item[kSecAttrAccount as String] as? String,
                  let data = item[kSecValueData as String] as? Data else { continue }
            accounts[account] = data
        }
        return hasKey(accounts: accounts, prefix: prefix)
        #else
        return false
        #endif
    }
}
