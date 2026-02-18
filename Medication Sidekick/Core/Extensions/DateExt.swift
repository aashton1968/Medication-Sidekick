//
//  DateExt.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2024-04-22.
//

import Foundation

extension Date {

    func localDate() -> Date {
        let nowUTC = Date()
        let timeZoneOffset = Double(TimeZone.current.secondsFromGMT(for: nowUTC))
        guard let localDate = Calendar.current.date(byAdding: .second, value: Int(timeZoneOffset), to: nowUTC) else {return Date()}

        return localDate
    }

    func nowMinusXHours(value: Double) -> Date {
        let nowUTC = Date()
        let expiryTime: Int = -(60 * Int(value))

        guard let nowMinusXHours = Calendar.current.date(byAdding: .minute, value: expiryTime, to: nowUTC)  else { return Date() }

        return nowMinusXHours
    }

    func adding(minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: self)!
    }

    func adding(hours: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: hours, to: self)!
    }

    func getHour() -> Int {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self)

        return hour
    }
    func getMinute() -> Int {
        let calendar = Calendar.current
        let min = calendar.component(.minute, from: self)

        return min
    }

    func makeDate(year: Int, month: Int, day: Int, hr: Int, min: Int, sec: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        // calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: year, month: month, day: day, hour: hr, minute: min, second: sec)
        return calendar.date(from: components)!
    }

    func UnixDate(unixDate: String) -> Date {
        let pattern = #"Date\((\d+)([+-]\d{4})?\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: unixDate, range: NSRange(unixDate.startIndex..., in: unixDate)),
              let range = Range(match.range(at: 1), in: unixDate),
              let millis = Double(unixDate[range]) else {
            return Date()
        }
        return Date(timeIntervalSince1970: millis / 1000.0)
    }

}

// Gets a local time data for a given UTC date
struct DateUtils {
    static func localDateString(from date: Date?) -> String {
        guard let date = date else { return "nil" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
