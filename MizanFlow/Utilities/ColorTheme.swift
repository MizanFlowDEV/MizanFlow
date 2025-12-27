import SwiftUI

/// Centralized color theme for DayType - ensures consistent colors across all views
struct ColorTheme {
    
    /// Returns the background color for a given DayType
    static func backgroundColor(for type: DayType) -> Color {
        switch type {
        case .workday:
            return Color.green.opacity(0.3)
        case .earnedOffDay:
            return Color.gray.opacity(0.3)
        case .vacation:
            return Color.yellow.opacity(0.3)
        case .training:
            return Color.orange.opacity(0.3)
        case .eidHoliday:
            return Color.yellow
        case .nationalDay:
            return Color.blue.opacity(0.7)
        case .foundingDay:
            return Color.purple.opacity(0.5)
        case .autoRescheduled:
            return Color.blue.opacity(0.3)
        case .companyOff:
            return Color.teal.opacity(0.3)
        case .manualOverride:
            return Color.red.opacity(0.3)
        case .ramadan:
            return Color.gray.opacity(0.5)
        }
    }
    
    /// Returns the text color for a given DayType
    static func textColor(for type: DayType) -> Color {
        switch type {
        case .eidHoliday, .nationalDay, .foundingDay:
            return .black
        default:
            return .primary
        }
    }
    
    /// Returns the foreground color for a given DayType (for labels, icons, etc.)
    static func foregroundColor(for type: DayType) -> Color {
        switch type {
        case .workday:
            return Color.green
        case .earnedOffDay:
            return Color.gray
        case .vacation:
            return Color.yellow
        case .training:
            return Color.orange
        case .eidHoliday:
            return Color.yellow
        case .nationalDay:
            return Color.blue
        case .foundingDay:
            return Color.purple
        case .autoRescheduled:
            return Color.blue
        case .companyOff:
            return Color.teal
        case .manualOverride:
            return Color.red
        case .ramadan:
            return Color.gray
        }
    }
    
    /// Returns the legend color for a given DayType (used in calendar legend)
    static func legendColor(for type: DayType) -> Color {
        return backgroundColor(for: type)
    }
}



