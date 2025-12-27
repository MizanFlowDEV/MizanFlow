import Foundation

/// Utilities for input validation and sanitization
struct ValidationUtilities {
    
    // MARK: - Salary Validation
    
    static func validateSalary(_ amount: Double) -> ValidationResult {
        if amount < 0 {
            return .invalid(NSLocalizedString("Salary cannot be negative", comment: "Negative salary error"))
        }
        if amount > 1_000_000 {
            return .invalid(NSLocalizedString("Salary amount seems unusually high. Please verify.", comment: "High salary warning"))
        }
        return .valid
    }
    
    static func validatePercentage(_ percentage: Double, min: Double = 0, max: Double = 100) -> ValidationResult {
        if percentage < min {
            return .invalid(NSLocalizedString("Percentage must be at least \(Int(min))%", comment: "Percentage too low"))
        }
        if percentage > max {
            return .invalid(NSLocalizedString("Percentage must be at most \(Int(max))%", comment: "Percentage too high"))
        }
        return .valid
    }
    
    static func validateHomeLoanPercentage(_ percentage: Double) -> ValidationResult {
        return validatePercentage(percentage, min: 0, max: 50)
    }
    
    static func validateESPPPercentage(_ percentage: Double) -> ValidationResult {
        return validatePercentage(percentage, min: 0, max: 10)
    }
    
    static func validateSpecialOperationsPercentage(_ percentage: Double) -> ValidationResult {
        let allowedValues = [5.0, 7.0, 10.0]
        if !allowedValues.contains(percentage) {
            return .invalid(NSLocalizedString("Special Operations percentage must be 5%, 7%, or 10%", comment: "Invalid special ops percentage"))
        }
        return .valid
    }
    
    // MARK: - Hours Validation
    
    static func validateHours(_ hours: Double) -> ValidationResult {
        if hours < 0 {
            return .invalid(NSLocalizedString("Hours cannot be negative", comment: "Negative hours error"))
        }
        if hours > 24 {
            return .invalid(NSLocalizedString("Hours cannot exceed 24 per day", comment: "Hours too high"))
        }
        return .valid
    }
    
    // MARK: - Date Validation
    
    static func validateDateRange(start: Date, end: Date) -> ValidationResult {
        if start > end {
            return .invalid(NSLocalizedString("Start date must be before end date", comment: "Invalid date range"))
        }
        return .valid
    }
    
    static func validateDateNotInPast(_ date: Date, allowPast: Bool = true) -> ValidationResult {
        if !allowPast && date < Date() {
            return .invalid(NSLocalizedString("Date cannot be in the past", comment: "Past date error"))
        }
        return .valid
    }
    
    // MARK: - Amount Validation
    
    static func validateAmount(_ amount: Double, min: Double = 0) -> ValidationResult {
        if amount < min {
            return .invalid(NSLocalizedString("Amount must be at least \(FormattingUtilities.formatCurrency(min))", comment: "Amount too low"))
        }
        if amount > 1_000_000 {
            return .invalid(NSLocalizedString("Amount seems unusually high. Please verify.", comment: "Amount too high"))
        }
        return .valid
    }
    
    // MARK: - String Validation
    
    static func validateNonEmptyString(_ string: String, fieldName: String) -> ValidationResult {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .invalid(NSLocalizedString("\(fieldName) cannot be empty", comment: "Empty field error"))
        }
        return .valid
    }
    
    static func sanitizeString(_ string: String) -> String {
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Combined Validation
    
    static func validateAll(_ results: [ValidationResult]) -> ValidationResult {
        for result in results {
            if case .invalid(let message) = result {
                return .invalid(message)
            }
        }
        return .valid
    }
}

// MARK: - Validation Result

enum ValidationResult {
    case valid
    case invalid(String)
    
    var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }
    
    var errorMessage: String? {
        if case .invalid(let message) = self {
            return message
        }
        return nil
    }
}



