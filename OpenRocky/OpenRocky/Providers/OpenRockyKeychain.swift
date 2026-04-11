//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
import Security

struct OpenRockyKeychain {
    static let live = OpenRockyKeychain()

    private let service = "com.xnu.rocky"

    func value(for account: String) -> String? {
        var query = lookupQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return string
    }

    func set(_ value: String, for account: String) {
        let data = Data(value.utf8)

        // Try to update existing item first
        let query = lookupQuery(account: account)
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        // Item does not exist — add with kSecAttrAccessibleAfterFirstUnlock
        // so it persists across app reinstalls.
        var addQuery = lookupQuery(account: account)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    func removeValue(for account: String) {
        SecItemDelete(lookupQuery(account: account) as CFDictionary)
    }

    /// Migrate existing keychain items to use `kSecAttrAccessibleAfterFirstUnlock`.
    /// Call once during app launch. Items that already have this accessibility are untouched.
    func migrateAccessibility() {
        // Query all items for this service
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else { return }

        for item in items {
            guard let account = item[kSecAttrAccount as String] as? String,
                  let data = item[kSecValueData as String] as? Data else { continue }

            // Check current accessibility
            let currentAccessible = item[kSecAttrAccessible as String] as? String
            let target = kSecAttrAccessibleAfterFirstUnlock as String
            if currentAccessible == target { continue }

            // Delete and re-add with correct accessibility
            let deleteQuery = lookupQuery(account: account)
            SecItemDelete(deleteQuery as CFDictionary)

            var addQuery = lookupQuery(account: account)
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    /// Base query for lookup/update/delete (no accessibility filter).
    private func lookupQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
