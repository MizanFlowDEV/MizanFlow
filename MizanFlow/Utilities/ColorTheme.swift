import SwiftUI

/// Centralized color theme for DayType - ensures consistent colors across all views
/// Uses DesignTokens for light/dark aware colors
struct ColorTheme {
    
    /// Returns the background color for a given DayType
    /// Uses subtle opacity for better readability
    static func backgroundColor(for type: DayType) -> Color {
        switch type {
        case .workday:
            return DesignTokens.Color.workday.opacity(0.2)
        case .earnedOffDay:
            return DesignTokens.Color.offDay.opacity(0.2)
        case .vacation:
            return DesignTokens.Color.vacation.opacity(0.2)
        case .training:
            return DesignTokens.Color.training.opacity(0.2)
        case .eidHoliday:
            return DesignTokens.Color.vacation.opacity(0.4)
        case .nationalDay:
            return DesignTokens.Color.holiday.opacity(0.4)
        case .foundingDay:
            return DesignTokens.Color.holiday.opacity(0.35)
        case .autoRescheduled:
            return DesignTokens.Color.holiday.opacity(0.2)
        case .companyOff:
            return DesignTokens.Color.offDay.opacity(0.25)
        case .manualOverride:
            return DesignTokens.Color.override.opacity(0.2)
        case .ramadan:
            return DesignTokens.Color.offDay.opacity(0.3)
        }
    }
    
    /// Returns the text color for a given DayType
    static func textColor(for type: DayType) -> Color {
        switch type {
        case .eidHoliday, .nationalDay, .foundingDay:
            // Use high contrast text for prominent holidays
            return DesignTokens.Color.textPrimary
        default:
            return DesignTokens.Color.textPrimary
        }
    }
    
    /// Returns the foreground color for a given DayType (for labels, icons, etc.)
    static func foregroundColor(for type: DayType) -> Color {
        switch type {
        case .workday:
            return DesignTokens.Color.workday
        case .earnedOffDay:
            return DesignTokens.Color.offDay
        case .vacation:
            return DesignTokens.Color.vacation
        case .training:
            return DesignTokens.Color.training
        case .eidHoliday:
            return DesignTokens.Color.vacation
        case .nationalDay:
            return DesignTokens.Color.holiday
        case .foundingDay:
            return DesignTokens.Color.holiday
        case .autoRescheduled:
            return DesignTokens.Color.holiday
        case .companyOff:
            return DesignTokens.Color.offDay
        case .manualOverride:
            return DesignTokens.Color.override
        case .ramadan:
            return DesignTokens.Color.offDay
        }
    }
    
    /// Returns the legend color for a given DayType (used in calendar legend)
    static func legendColor(for type: DayType) -> Color {
        return backgroundColor(for: type)
    }
    
    /// Returns the indicator color for a given DayType (for calendar cell indicators)
    static func indicatorColor(for type: DayType) -> Color {
        return foregroundColor(for: type)
    }
}



