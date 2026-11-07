//
//  MedicationTimeZoneTests.swift
//  Medication Sidekick Tests
//
//  Covers the timezone-sync fix: MedicationDoseGenerator.retimeStaleDoses().
//

import Testing
import SwiftData
import Foundation
@testable import Medication_Sidekick

// MARK: - MedicationDoseGenerator.retimeStaleDoses

@MainActor
struct MedicationDoseGeneratorRetimeTests {

    // MARK: Fixtures

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Medication.self, MedicationDose.self, MealTimeSetting.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// "Today" built under the device's live calendar, matching how doses are stamped.
    private func today(hour: Int, minute: Int, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)!
    }

    // MARK: Tests

    @Test func `corrects a scheduled dose whose stored hour no longer matches its meal setting`() throws {
        let context = try makeContext()
        let medication = Medication(name: "Vitamin D", dosage: "1000IU", meals: [.breakfast])
        context.insert(medication)

        // Stamped as 9:00 while the device was in some other offset; breakfast defaults to 7:00.
        let staleDose = MedicationDose(medication: medication, mealTime: .breakfast, scheduledDate: today(hour: 9, minute: 0))
        context.insert(staleDose)

        let didChange = try MedicationDoseGenerator.retimeStaleDoses(modelContext: context)

        #expect(didChange == true)
        let corrected = Calendar.current.dateComponents([.hour, .minute], from: staleDose.scheduledDate)
        #expect(corrected.hour == 7)
        #expect(corrected.minute == 0)
    }

    @Test func `leaves a taken dose untouched even if its stored hour is stale`() throws {
        let context = try makeContext()
        let medication = Medication(name: "Vitamin D", dosage: "1000IU", meals: [.breakfast])
        context.insert(medication)

        let originalDate = today(hour: 9, minute: 0)
        let takenDose = MedicationDose(
            medication: medication,
            mealTime: .breakfast,
            scheduledDate: originalDate,
            status: .taken
        )
        context.insert(takenDose)

        let didChange = try MedicationDoseGenerator.retimeStaleDoses(modelContext: context)

        #expect(didChange == false)
        #expect(takenDose.scheduledDate == originalDate)
    }

    @Test func `leaves a skipped dose untouched even if its stored hour is stale`() throws {
        let context = try makeContext()
        let medication = Medication(name: "Vitamin D", dosage: "1000IU", meals: [.breakfast])
        context.insert(medication)

        let originalDate = today(hour: 9, minute: 0)
        let skippedDose = MedicationDose(
            medication: medication,
            mealTime: .breakfast,
            scheduledDate: originalDate,
            status: .skipped
        )
        context.insert(skippedDose)

        let didChange = try MedicationDoseGenerator.retimeStaleDoses(modelContext: context)

        #expect(didChange == false)
        #expect(skippedDose.scheduledDate == originalDate)
    }

    @Test func `is a no-op when the scheduled dose already matches its meal setting`() throws {
        let context = try makeContext()
        let medication = Medication(name: "Vitamin D", dosage: "1000IU", meals: [.breakfast])
        context.insert(medication)

        let correctDate = today(hour: 7, minute: 0)
        let dose = MedicationDose(medication: medication, mealTime: .breakfast, scheduledDate: correctDate)
        context.insert(dose)

        let didChange = try MedicationDoseGenerator.retimeStaleDoses(modelContext: context)

        #expect(didChange == false)
        #expect(dose.scheduledDate == correctDate)
    }

    @Test func `prefers a custom MealTimeSetting hour over the MealTime enum default`() throws {
        let context = try makeContext()
        let medication = Medication(name: "Vitamin D", dosage: "1000IU", meals: [.breakfast])
        context.insert(medication)

        // User moved their "breakfast" slot to 8:15; the enum default (7:00) should be ignored.
        let customSetting = MealTimeSetting(name: "Breakfast", key: "breakfast", hour: 8, minute: 15, sortOrder: 0)
        context.insert(customSetting)

        let staleDose = MedicationDose(medication: medication, mealTime: .breakfast, scheduledDate: today(hour: 7, minute: 0))
        context.insert(staleDose)

        let didChange = try MedicationDoseGenerator.retimeStaleDoses(modelContext: context)

        #expect(didChange == true)
        let corrected = Calendar.current.dateComponents([.hour, .minute], from: staleDose.scheduledDate)
        #expect(corrected.hour == 8)
        #expect(corrected.minute == 15)
    }

    @Test func `ignores a dose whose meal key matches neither a setting nor the MealTime enum`() throws {
        let context = try makeContext()
        let medication = Medication(name: "Vitamin D", dosage: "1000IU", meals: [.breakfast])
        context.insert(medication)

        let originalDate = today(hour: 9, minute: 0)
        let orphanDose = MedicationDose(medication: medication, mealKey: "midMorningSnack", scheduledDate: originalDate)
        context.insert(orphanDose)

        let didChange = try MedicationDoseGenerator.retimeStaleDoses(modelContext: context)

        #expect(didChange == false)
        #expect(orphanDose.scheduledDate == originalDate)
    }

    @Test func `ignores sub-minute drift so it does not fight floating point noise`() throws {
        let context = try makeContext()
        let medication = Medication(name: "Vitamin D", dosage: "1000IU", meals: [.breakfast])
        context.insert(medication)

        let almostCorrectDate = today(hour: 7, minute: 0).addingTimeInterval(30) // 30s off, under the 60s threshold
        let dose = MedicationDose(medication: medication, mealTime: .breakfast, scheduledDate: almostCorrectDate)
        context.insert(dose)

        let didChange = try MedicationDoseGenerator.retimeStaleDoses(modelContext: context)

        #expect(didChange == false)
        #expect(dose.scheduledDate == almostCorrectDate)
    }
}

// MARK: - AppStartupSequence.retimeDosesForTimeZoneChangeIfNeeded

@MainActor
struct TimeZoneChangeResyncTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Medication.self, MedicationDose.self, MealTimeSetting.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private final class Counter { var value = 0 }

    @Test func `a changed time zone triggers a notification resync even when no dose moved`() async throws {
        let context = try makeContext()
        UserDefaults.standard.set("Pacific/Kiritimati", forKey: "lastKnownTimeZoneIdentifier")

        let counter = Counter()
        let token = NotificationCenter.default.addObserver(forName: .medicationDidChange, object: nil, queue: nil) { _ in
            counter.value += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }

        await AppStartupSequence.retimeDosesForTimeZoneChangeIfNeeded(modelContext: context)

        #expect(counter.value == 1)
        #expect(UserDefaults.standard.string(forKey: "lastKnownTimeZoneIdentifier") == TimeZone.current.identifier)
    }

    @Test func `an unchanged time zone with nothing stale does not trigger a resync`() async throws {
        let context = try makeContext()
        UserDefaults.standard.set(TimeZone.current.identifier, forKey: "lastKnownTimeZoneIdentifier")

        let counter = Counter()
        let token = NotificationCenter.default.addObserver(forName: .medicationDidChange, object: nil, queue: nil) { _ in
            counter.value += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }

        await AppStartupSequence.retimeDosesForTimeZoneChangeIfNeeded(modelContext: context)

        #expect(counter.value == 0)
    }
}
