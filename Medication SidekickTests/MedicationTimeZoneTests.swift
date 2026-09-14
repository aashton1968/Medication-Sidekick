//
//  MedicationTimeZoneTests.swift
//  Medication Sidekick Tests
//
//  Covers the timezone-sync fix: Medication.schedulingCalendar and
//  MedicationDoseGenerator.retimeStaleDoses().
//

import Testing
import SwiftData
import Foundation
@testable import Medication_Sidekick

// MARK: - Medication.schedulingCalendar

@MainActor
struct MedicationSchedulingCalendarTests {

    @Test func `schedulingCalendar follows device time zone by default`() {
        let sut = Medication(name: "Amoxicillin", dosage: "500mg")
        #expect(sut.schedulingCalendar.timeZone == Calendar.current.timeZone)
    }

    @Test func `schedulingCalendar falls back to device time zone when no home zone is set`() {
        let sut = Medication(name: "Amoxicillin", dosage: "500mg", followsDeviceTimeZone: false)
        #expect(sut.homeTimeZoneIdentifier == nil)
        #expect(sut.schedulingCalendar.timeZone == Calendar.current.timeZone)
    }

    @Test func `schedulingCalendar falls back to device time zone when the stored identifier is invalid`() {
        let sut = Medication(
            name: "Amoxicillin",
            dosage: "500mg",
            followsDeviceTimeZone: false,
            homeTimeZoneIdentifier: "Not/A_Real_Zone"
        )
        #expect(sut.schedulingCalendar.timeZone == Calendar.current.timeZone)
    }

    @Test func `schedulingCalendar pins to the home time zone when device following is off`() {
        let sut = Medication(
            name: "Amoxicillin",
            dosage: "500mg",
            followsDeviceTimeZone: false,
            homeTimeZoneIdentifier: "Pacific/Auckland"
        )
        #expect(sut.schedulingCalendar.timeZone == TimeZone(identifier: "Pacific/Auckland"))
    }

    @Test func `schedulingCalendar ignores a stored home zone when still following the device`() {
        // A home zone can be left behind from a previous "Fixed schedule" period; it should
        // only take effect once followsDeviceTimeZone is turned off again.
        let sut = Medication(
            name: "Amoxicillin",
            dosage: "500mg",
            followsDeviceTimeZone: true,
            homeTimeZoneIdentifier: "Pacific/Auckland"
        )
        #expect(sut.schedulingCalendar.timeZone == Calendar.current.timeZone)
    }
}

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

    @Test func `fixed-time-zone medication is retimed against its home zone, not the device zone`() throws {
        let context = try makeContext()
        let homeZoneIdentifier = "Pacific/Auckland"
        let homeZone = TimeZone(identifier: homeZoneIdentifier)!
        let medication = Medication(
            name: "Antibiotic",
            dosage: "250mg",
            meals: [.breakfast],
            followsDeviceTimeZone: false,
            homeTimeZoneIdentifier: homeZoneIdentifier
        )
        context.insert(medication)

        // Build "today" under the device's calendar (as generation does) but with a
        // deliberately wrong hour, so the pass has something to correct.
        let staleDose = MedicationDose(medication: medication, mealTime: .breakfast, scheduledDate: today(hour: 9, minute: 0))
        context.insert(staleDose)

        let didChange = try MedicationDoseGenerator.retimeStaleDoses(modelContext: context)

        #expect(didChange == true)
        var homeCalendar = Calendar.current
        homeCalendar.timeZone = homeZone
        let corrected = homeCalendar.dateComponents([.hour, .minute], from: staleDose.scheduledDate)
        #expect(corrected.hour == 7)
        #expect(corrected.minute == 0)
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
