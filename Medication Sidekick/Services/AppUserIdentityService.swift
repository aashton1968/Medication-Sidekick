//
//  AppUserIdentityService.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-03-11.
//

import Foundation

final class AppUserIdentityService {
    static let shared = AppUserIdentityService()

    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private let storageKey = AppStorageKeys.revenueCatAppUserID.rawValue

    private init() {}

    func getOrCreateAppUserID() -> String {
        if let id = readStoredID() {
            persist(id)
            return id
        }

        let generatedID = UUID().uuidString
        persist(generatedID)
        return generatedID
    }

    private func readStoredID() -> String? {
        if let iCloudValue = ubiquitousStore.string(forKey: storageKey),
           !iCloudValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return iCloudValue
        }

        if let localValue = defaults.string(forKey: storageKey),
           !localValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return localValue
        }

        return nil
    }

    private func persist(_ id: String) {
        defaults.set(id, forKey: storageKey)
        ubiquitousStore.set(id, forKey: storageKey)
        ubiquitousStore.synchronize()
    }
}
