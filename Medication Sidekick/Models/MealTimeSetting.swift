//
//  MealTimeSetting.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-18.
//

import Foundation
import SwiftData

@Model
final class MealTimeSetting {

    // MARK: - Identifiers
    var id: UUID = UUID()

    // MARK: - Core Fields
    var name: String = ""
    var key: String = ""
    var hour: Int = 8
    var minute: Int = 0
    var sortOrder: Int = 0
    var symbolName: String = "fork.knife"

    // MARK: - Computed

    var defaultDateComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }

    var displayTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        if let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) {
            return formatter.string(from: date)
        }
        return String(format: "%d:%02d", hour, minute)
    }

    /// Generates a camelCase key from a display name (e.g. "Morning Snack" → "morningSnack")
    static func generateKey(from name: String) -> String {
        let words = name.split(separator: " ")
        guard let first = words.first else { return name.lowercased() }
        let head = first.lowercased()
        let tail = words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined()
        return head + tail
    }

    // MARK: - Init

    init(
        name: String,
        key: String? = nil,
        hour: Int,
        minute: Int,
        sortOrder: Int,
        symbolName: String = "fork.knife"
    ) {
        self.id = UUID()
        self.name = name
        self.key = key ?? Self.generateKey(from: name)
        self.hour = hour
        self.minute = minute
        self.sortOrder = sortOrder
        self.symbolName = symbolName
    }
}
