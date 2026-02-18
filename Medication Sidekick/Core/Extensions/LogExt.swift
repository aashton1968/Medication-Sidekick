import os.log
import Foundation
import SwiftUI



extension Logger {

    /// Using your bundle identifier is a great way to ensure a unique identifier.
    private static var subsystem = Bundle.main.bundleIdentifier!

    /// Custom logging function to include timestamp with timezone
    private func logWithTimestamp(_ message: String, level: OSLogType) {
        
		// Create a date formatter
		let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)

        let formattedMessage = "\(timestamp): \(message)"
		
        // Log the message
        log(level: level, "\(formattedMessage, privacy: .public)")
    }

    /// Logs the view cycles like a view that appeared.
    static let viewCycle = Logger(subsystem: subsystem, category: "viewcycle")

    /// All logs related to tracking and analytics.
    static let api = Logger(subsystem: subsystem, category: "API")

    /// All logs related to models
    static let model = Logger(subsystem: subsystem, category: "Model")

    /// All logs related to UI
    static let ui = Logger(subsystem: subsystem, category: "UI")

    /// All logs related to data items async
    static let data = Logger(subsystem: subsystem, category: "Data")

    /// All logs related to services
    static let service = Logger(subsystem: subsystem, category: "Service")

    /// All logs related to charts
    static let cht = Logger(subsystem: subsystem, category: "Chart")

    /// All logs related to background Tasks
    static let bgt = Logger(subsystem: subsystem, category: "BackgroundTask")
    
    /// All logs related to testing
    static let test = Logger(subsystem: subsystem, category: "Test")

    /// Logs the view cycles like a view that appeared.
    static let healthKit = Logger(subsystem: subsystem, category: "HealthKit")
    
    /// Example usage of the custom log function
    func logInfo(_ message: String) {
        logWithTimestamp(message, level: .info)
    }

    // Use this for debug logs with function, file, and line info
	func logDebug(_ message: String,
								function: String = #function,
								file: String = #file,
								line: Int = #line) {
		
		// Extract the filename from the file path
		let filename = (file as NSString).lastPathComponent
		
		// Format the message with timestamp
		let message = String("\(message): \(function): [\(filename): line \(line)]")
		
		logWithTimestamp(message, level: .debug)
	}

    
    func logError(_ message: String) {
        logWithTimestamp(message, level: .error)
    }

    // Add more logging levels as needed (e.g., `logWarning`, `logFault`, etc.)
}

