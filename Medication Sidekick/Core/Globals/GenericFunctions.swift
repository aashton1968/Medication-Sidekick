//
//  GenericFunctions.swift
//  Diabetic Sidekick
//
//  Created by Alan Ashton on 2025-09-15.
//
import Foundation
import os.log
import SwiftData

struct GenericFunctions {
    
   
    static func IntToString(value: Int) -> String {
        let myString = "\(value)"
        return myString
    }
    
    static func doubleToString(_ value: Double) -> String {
           value.formatted(.number.precision(.fractionLength(1)))
       }

   static func isDateChanged(oldDate: Date, newDate: Date) -> Bool {
       let calendar = Calendar.current

       let oldMonth = calendar.component(.month, from: oldDate)
       let newMonth = calendar.component(.month, from: newDate)
       let oldDay = calendar.component(.day, from: oldDate)
       let newDay = calendar.component(.day, from: newDate)

       let oldHour = calendar.component(.hour, from: oldDate)
       let newHour = calendar.component(.hour, from: newDate)
       let oldMinute = calendar.component(.minute, from: oldDate)
       let newMinute = calendar.component(.minute, from: newDate)

       return oldMonth == newMonth &&
              oldDay == newDay &&
              (oldHour != newHour || oldMinute != newMinute)
   }
}
