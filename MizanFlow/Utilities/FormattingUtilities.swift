import Foundation
import SwiftUI

/// Centralized formatting utilities for consistent date, currency, and number formatting across the app
struct FormattingUtilities {
    
    // MARK: - Shared Formatters (Thread-safe, cached instances)
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    private static let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "SAR"
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    private static let percentageFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    // MARK: - Date Formatting
    
    /// Formats a date using medium date style (e.g., "Jan 15, 2025")
    static func formatDate(_ date: Date, locale: Locale? = nil) -> String {
        let formatter = dateFormatter
        if let locale = locale {
            formatter.locale = locale
        }
        return formatter.string(from: date)
    }
    
    /// Formats a date using short date style (e.g., "1/15/25")
    static func formatShortDate(_ date: Date, locale: Locale? = nil) -> String {
        let formatter = shortDateFormatter
        if let locale = locale {
            formatter.locale = locale
        }
        return formatter.string(from: date)
    }
    
    /// Formats a date as month and year (e.g., "January 2025")
    static func formatMonth(_ date: Date, locale: Locale? = nil) -> String {
        let formatter = monthYearFormatter
        if let locale = locale {
            formatter.locale = locale
        }
        return formatter.string(from: date)
    }
    
    /// Formats a date for export (e.g., "2025-01-15")
    static func formatExportDate(_ date: Date) -> String {
        return exportDateFormatter.string(from: date)
    }
    
    // MARK: - Currency Formatting
    
    /// Formats a currency amount in SAR
    static func formatCurrency(_ amount: Double, locale: Locale? = nil) -> String {
        let formatter = currencyFormatter
        if let locale = locale {
            formatter.locale = locale
        }
        return formatter.string(from: NSNumber(value: amount)) ?? "SAR 0.00"
    }
    
    // MARK: - Percentage Formatting
    
    /// Formats a percentage value (input should be the percentage value, e.g., 25.5 for 25.5%)
    static func formatPercentage(_ value: Double, locale: Locale? = nil) -> String {
        let formatter = percentageFormatter
        if let locale = locale {
            formatter.locale = locale
        }
        // Convert percentage value to decimal (e.g., 25.5 -> 0.255)
        return formatter.string(from: NSNumber(value: value / 100)) ?? "0%"
    }
    
    // MARK: - Locale Support
    
    /// Updates all formatters to use the specified locale
    static func updateLocale(_ locale: Locale) {
        dateFormatter.locale = locale
        monthYearFormatter.locale = locale
        shortDateFormatter.locale = locale
        currencyFormatter.locale = locale
        percentageFormatter.locale = locale
    }
}



