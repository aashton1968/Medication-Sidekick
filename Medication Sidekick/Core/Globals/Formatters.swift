//
//  Formatters.swift
//  Diabetic Sidekick
//
//  Created by Alan Ashton on 2025-09-15.
//

import Foundation

struct Formatters {
    
    static var numberFormatter0d: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        formatter.generatesDecimalNumbers = false
        return formatter
     }()

    static var numberFormatter1d: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        formatter.roundingMode = .halfUp
        formatter.generatesDecimalNumbers = false
        formatter.zeroSymbol = ""
        return formatter
    }()
    
    static var numberFormatter2d: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 1
        formatter.generatesDecimalNumbers = false
        formatter.zeroSymbol = ""
        return formatter
     }()
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium

        return formatter
    }()

    static let dateFormatterCapsule: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"

        return formatter
    }()
    
    static let dateFormatterVShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"

        return formatter
    }()

 
}
