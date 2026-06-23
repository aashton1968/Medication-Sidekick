//
//  GenericExtensions.swift
//  Diabetic Sidekick
//
//  Created by Alan Ashton on 2024-04-22.
//

import Foundation
import SwiftUI
import SwiftData
import os.log

extension Double {
    func formatDouble(minimumIntegerDigits: Int, minimumFractionDigits: Int, maximumFractionDigits: Int=2) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumIntegerDigits = minimumIntegerDigits
        numberFormatter.minimumFractionDigits = minimumFractionDigits
        numberFormatter.maximumFractionDigits = maximumFractionDigits

        return numberFormatter.string(for: self) ?? ""
    }

}

extension Double {
    /// Convert mmol/L to mg/dL using standard conversion factor and rounding.
    var asMGDL: Int {
        let converted = (self * 18.01559).rounded()
        return converted.safeInt
    }
    /// Convert mg/dL to mmol/L using standard conversion factor and rounding.
    var asMMOL: Double {
        (self / 18.01559 * 10).rounded() / 10
    }
    
    func rounded(toPlaces places: Int) -> Double {
            let multiplier = pow(10.0, Double(places))
            return (self * multiplier).rounded() / multiplier
        }

    /// Safe Double -> Int conversion that handles NaN/Infinity and overflow.
    /// Uses truncation (same behavior as Int(Double) for finite in-range values).
    nonisolated var safeInt: Int {
        guard isFinite else { return 0 }
        if self >= Double(Int.max) { return Int.max }
        if self <= Double(Int.min) { return Int.min }
        return Int(self)
    }
}

extension Int {
    var asMMOL: Double {
        (Double(self) / 18.01559 * 10).rounded() / 10
    }
}

extension Array {

    func sliced(by dateComponents: Set<Calendar.Component>, for key: KeyPath<Element, Date>) -> [Date: [Element]] {
        let initial: [Date: [Element]] = [:]
        let groupedByDateComponents = reduce(into: initial) { acc, cur in
            let components = Calendar.current.dateComponents(dateComponents, from: cur[keyPath: key])
            guard let date = Calendar.current.date(from: components) else { return }
            let existing = acc[date] ?? []
            acc[date] = existing + [cur]
        }

        return groupedByDateComponents
    }
}

extension Array where Iterator.Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Iterator.Element> = []
        return filter { seen.insert($0).inserted }
    }
}

extension View {
    func hidden(_ shouldHide: Bool) -> some View {
        opacity(shouldHide ? 0 : 1)
    }
}

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

enum MyError: Error {
    case runtimeError(String)
}

extension String {
  func toMarkdown() -> AttributedString {
    do {
      return try AttributedString(markdown: self)
    } catch {
      print("Error parsing Markdown for string \(self): \(error)")
      return AttributedString(self)
    }
  }
}

extension Bundle {
    var iconFileName: String? {
        guard let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
              let iconFileName = iconFiles.last
        else { return nil }
        return iconFileName
    }
}
