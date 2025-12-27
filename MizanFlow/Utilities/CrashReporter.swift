import Foundation
import os
import Darwin

private typealias CrashReporterSignalHandler = @convention(c) (Int32) -> Void

private let crashReporterSignalHandler: CrashReporterSignalHandler = { signalNumber in
    CrashReporter.shared.logSignal(signalNumber)
    // Re-raise the signal to allow default handling
    signal(signalNumber, SIG_DFL)
    raise(signalNumber)
}

/// Crash reporting and error tracking utility
/// In production, this would integrate with a service like Firebase Crashlytics
class CrashReporter {
    static let shared = CrashReporter()
    
    private let logger = AppLogger.general
    
    private init() {
        setupCrashHandling()
    }
    
    // MARK: - Setup
    
    private func setupCrashHandling() {
        // Set up uncaught exception handler
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.logException(exception)
        }
        
        // Set up signal handlers for crashes
        signal(SIGABRT, crashReporterSignalHandler)
        signal(SIGILL, crashReporterSignalHandler)
        signal(SIGSEGV, crashReporterSignalHandler)
        signal(SIGFPE, crashReporterSignalHandler)
        signal(SIGBUS, crashReporterSignalHandler)
        signal(SIGPIPE, crashReporterSignalHandler)
    }
    
    // MARK: - Logging
    
    func logException(_ exception: NSException) {
        let exceptionInfo = """
        Exception: \(exception.name.rawValue)
        Reason: \(exception.reason ?? "Unknown")
        Call Stack:
        \(exception.callStackSymbols.joined(separator: "\n"))
        """
        
        logger.critical("Uncaught exception: \(exceptionInfo, privacy: .public)")
        
        // In production, send to crash reporting service
        // FirebaseCrashlytics.crashlytics().record(error: exception)
    }
    
    func logSignal(_ signal: Int32) {
        let signalName: String
        switch signal {
        case SIGABRT: signalName = "SIGABRT"
        case SIGILL: signalName = "SIGILL"
        case SIGSEGV: signalName = "SIGSEGV"
        case SIGFPE: signalName = "SIGFPE"
        case SIGBUS: signalName = "SIGBUS"
        case SIGPIPE: signalName = "SIGPIPE"
        default: signalName = "Unknown"
        }
        
        logger.critical("Signal received: \(signalName) (\(signal))")
        
        // In production, send to crash reporting service
    }
    
    func logError(_ error: Error, context: String = "") {
        let errorInfo = """
        Error in \(context):
        \(error.localizedDescription)
        \(error)
        """
        
        logger.error("\(errorInfo, privacy: .public)")
        
        // In production, send to crash reporting service
        // FirebaseCrashlytics.crashlytics().record(error: error)
    }
    
    func setUserIdentifier(_ identifier: String) {
        // In production, set user identifier for crash reporting
        // FirebaseCrashlytics.crashlytics().setUserID(identifier)
        logger.debug("User identifier set: \(identifier, privacy: .public)")
    }
    
    func setCustomKey(_ key: String, value: String) {
        // In production, set custom key-value pairs
        // FirebaseCrashlytics.crashlytics().setCustomValue(value, forKey: key)
        logger.debug("Custom key set: \(key) = \(value, privacy: .public)")
    }
}


