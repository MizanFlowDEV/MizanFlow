import Foundation

/// Custom error types for the application
enum AppError: LocalizedError {
    case coreDataError(String)
    case validationError(String)
    case networkError(String)
    case fileError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .coreDataError(let message):
            return NSLocalizedString("Core Data Error: \(message)", comment: "Core Data error")
        case .validationError(let message):
            return NSLocalizedString("Validation Error: \(message)", comment: "Validation error")
        case .networkError(let message):
            return NSLocalizedString("Network Error: \(message)", comment: "Network error")
        case .fileError(let message):
            return NSLocalizedString("File Error: \(message)", comment: "File error")
        case .unknownError(let message):
            return NSLocalizedString("Unknown Error: \(message)", comment: "Unknown error")
        }
    }
    
    var failureReason: String? {
        switch self {
        case .coreDataError:
            return NSLocalizedString("A database operation failed", comment: "Core Data failure reason")
        case .validationError:
            return NSLocalizedString("The input data is invalid", comment: "Validation failure reason")
        case .networkError:
            return NSLocalizedString("A network operation failed", comment: "Network failure reason")
        case .fileError:
            return NSLocalizedString("A file operation failed", comment: "File failure reason")
        case .unknownError:
            return NSLocalizedString("An unexpected error occurred", comment: "Unknown failure reason")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .coreDataError:
            return NSLocalizedString("Please try again. If the problem persists, contact support.", comment: "Core Data recovery")
        case .validationError:
            return NSLocalizedString("Please check your input and try again.", comment: "Validation recovery")
        case .networkError:
            return NSLocalizedString("Please check your internet connection and try again.", comment: "Network recovery")
        case .fileError:
            return NSLocalizedString("Please check file permissions and try again.", comment: "File recovery")
        case .unknownError:
            return NSLocalizedString("Please try again. If the problem persists, restart the app.", comment: "Unknown recovery")
        }
    }
}



