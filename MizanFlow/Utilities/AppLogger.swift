import Foundation
import os

public enum AppLogger {
    private static let subsystem: String = {
        Bundle.main.bundleIdentifier ?? "MizanFlow"
    }()

    public static let coreData = Logger(subsystem: subsystem, category: "CoreData")
    public static let viewModel = Logger(subsystem: subsystem, category: "ViewModel")
    public static let ui = Logger(subsystem: subsystem, category: "UI")
    public static let engine = Logger(subsystem: subsystem, category: "Engine")
    public static let general = Logger(subsystem: subsystem, category: "General")
}



