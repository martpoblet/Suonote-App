import Foundation
import os

/// Centralized loggers (U-06). View in Console.app filtering by subsystem.
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Suonote"

    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let studio = Logger(subsystem: subsystem, category: "studio")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let general = Logger(subsystem: subsystem, category: "general")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
