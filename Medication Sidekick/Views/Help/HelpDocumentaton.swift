//
//  HelpDocumentaton.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-01-03.
//


import SwiftUI

struct HelpDocumentation {
    struct HelpPage: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let markdownURL: URL
        let browserURL: URL
    }
    
    static func localDoc(_ name: String) -> URL {
        if let url = Bundle.main.url(forResource: name, withExtension: "md") {
            return url
        }

        // 🚨 LOG MISSING FILE
        print("❌ Missing help markdown file in bundle:", name)

        // Fallback to an empty placeholder so SwiftUI doesn't crash
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing_help.md")

        if !FileManager.default.fileExists(atPath: temp.path) {
            try? "Help file '\(name)' is missing from the app bundle."
                .write(to: temp, atomically: true, encoding: .utf8)
        }

        return temp
    }
    
    static var defaultPage: HelpPage {
        helpPages.first!
    }

    static func page(named title: String) -> HelpPage? {
        helpPages.first { $0.title == title }
    }

    static let helpPages: [HelpPage] = [
        HelpPage(
            title: "Getting Started",
            markdownURL: localDoc("Home"),
            browserURL: URL(string: "https://github.com/aashton1968/Diabetic-Sidekick-Support/wiki/Home")!
        )
        
    ]
}


/*
 
 - [Getting Started](Home)
 - [Logbook Entries](Logbook-Entries)
 - [Charts & Insights](Charts-and-Insights)
 - [Meals](Meals)
 - [Ratios & Targets](Ratios-and-Targets)
 - [Dexcom Integration](Dexcom-Integration)
 - [Privacy & Security](Privacy-and-Security)

 ---

 ## Legal

 - [Privacy Policy](Legal-Privacy-Policy)
 - [Terms of Use](Legal-Terms-of-Use)
 - [Medical Disclaimer](Legal-Medical-Disclaimer)
 
 */
