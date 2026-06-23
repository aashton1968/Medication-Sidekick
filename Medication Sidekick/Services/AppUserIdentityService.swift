//
//  AppUserIdentityService.swift
//  Medication Sidekick
//
//  Stores the RevenueCat app user ID in the Keychain (primary) and in
//  NSUbiquitousKeyValueStore (cross-device fallback). UserDefaults is no
//  longer used because it is included in device backups and readable by
//  processes with the same App Group identifier.
//

import Foundation
import Security

final class AppUserIdentityService {
    static let shared = AppUserIdentityService()

    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let storageKey = AppStorageKeys.revenueCatAppUserID.rawValue
    private let keychainService = Bundle.main.bundleIdentifier ?? "com.alanashton.Medication-Sidekick"

    private init() {}

    func getOrCreateAppUserID() -> String {
        if let id = readStoredID() {
            persist(id)
            return id
        }
        let generated = UUID().uuidString
        persist(generated)
        return generated
    }

    // MARK: - Private

    private func readStoredID() -> String? {
        if let keychainValue = readFromKeychain(), !keychainValue.isEmpty { return keychainValue }
        if let iCloudValue = ubiquitousStore.string(forKey: storageKey), !iCloudValue.isEmpty { return iCloudValue }
        return nil
    }

    private func persist(_ id: String) {
        writeToKeychain(id)
        ubiquitousStore.set(id, forKey: storageKey)
        ubiquitousStore.synchronize()
    }

    // MARK: - Keychain

    private func readFromKeychain() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: storageKey,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    private func writeToKeychain(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: storageKey
        ]

        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }
}
