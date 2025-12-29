import Foundation

/// Centralized holiday detection service - single source of truth for all holiday logic
class HolidayService {
    static let shared = HolidayService()
    private init() {}
    
    // MARK: - Fixed Holidays
    
    /// Fixed holidays that occur on the same date every year
    private let fixedHolidays: [(month: Int, day: Int, type: HolidayType)] = [
        (2, 22, .foundingDay),      // Saudi Founding Day
        (9, 23, .nationalDay),       // Saudi National Day
    ]
    
    /// Company-specific fixed holidays
    private let companyFixedHolidays: [(month: Int, day: Int)] = [
        (1, 5),   // January 5
        (2, 23),  // Company Rescheduled Day Off
        (6, 9),   // Company Rescheduled Day Off
        (6, 10),  // Company Rescheduled Day Off
        (11, 16), // November 16
    ]
    
    // MARK: - Eid Holidays (Variable dates by year)
    
    /// Eid al-Fitr dates by year (approximate - should be updated annually)
    private let eidFitrDates: [Int: (month: Int, startDay: Int, endDay: Int)] = [
        2025: (3, 30, 2),  // March 30 - April 2, 2025
        2026: (3, 1, 7),   // March 1 - March 7, 2026
        // Add future years as needed
    ]
    
    /// Eid al-Adha dates by year (approximate - should be updated annually)
    private let eidAdhaDates: [Int: (month: Int, startDay: Int, endDay: Int)] = [
        2025: (6, 5, 8),   // June 5-8, 2025
        2026: (6, 21, 30), // June 21-30, 2026
        // Add future years as needed
    ]
    
    // MARK: - Ramadan Detection
    
    /// Ramadan dates by year
    /// Format: (startMonth, startDay, endDay)
    /// For single-month: endDay is in the same month (e.g., 2025: March 1-29)
    /// For cross-month: endDay is in the next month (e.g., 2026: February 1 - March 4)
    private let ramadanDates: [Int: (month: Int, startDay: Int, endDay: Int)] = [
        2025: (3, 1, 29),  // March 1 - March 29, 2025 (single month)
        2026: (2, 1, 4),   // February 1 - March 4, 2026 (cross-month: endDay is in next month)
        // Add future years as needed
    ]
    
    // MARK: - Public Holiday Detection
    
    /// Checks if a date is a public holiday (Eid, National Day, or Founding Day)
    func isPublicHoliday(_ date: Date) -> Bool {
        return isEidHoliday(date) || isNationalDay(date) || isFoundingDay(date)
    }
    
    /// Checks if a date is an Eid holiday
    func isEidHoliday(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return false
        }
        
        // Check Eid al-Fitr
        if let eidFitr = eidFitrDates[year] {
            // If endDay < startDay, Eid spans two months (e.g., March 30 - April 2)
            // Otherwise, Eid is in a single month (e.g., March 1-7)
            if eidFitr.endDay < eidFitr.startDay {
                // Cross-month: check start month from startDay, and next month up to endDay
                if month == eidFitr.month && day >= eidFitr.startDay {
                    return true
                }
                if month == eidFitr.month + 1 && day <= eidFitr.endDay {
                    return true
                }
            } else {
                // Same month: check only the start month from startDay to endDay
                if month == eidFitr.month && day >= eidFitr.startDay && day <= eidFitr.endDay {
                    return true
                }
            }
        }
        
        // Check Eid al-Adha
        if let eidAdha = eidAdhaDates[year] {
            if month == eidAdha.month && day >= eidAdha.startDay && day <= eidAdha.endDay {
                return true
            }
        }
        
        return false
    }
    
    /// Checks if a date is National Day
    func isNationalDay(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: date)
        return components.month == 9 && components.day == 23
    }
    
    /// Checks if a date is Founding Day
    func isFoundingDay(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: date)
        return components.month == 2 && components.day == 22
    }
    
    /// Checks if a date is a company-specific holiday
    func isCompanyHoliday(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: date)
        
        guard let month = components.month,
              let day = components.day else {
            return false
        }
        
        return companyFixedHolidays.contains { $0.month == month && $0.day == day }
    }
    
    /// Checks if a date is during Ramadan
    func isInRamadan(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return false
        }
        
        if let ramadan = ramadanDates[year] {
            // Check if date is in the start month
            if month == ramadan.month {
                // If endDay is small (<= 15), Ramadan likely spans two months
                // So include all days from startDay to end of month
                if ramadan.endDay <= 15 {
                    return day >= ramadan.startDay
                } else {
                    // Single month: check if day is within range
                    return day >= ramadan.startDay && day <= ramadan.endDay
                }
            }
            // Check if date is in the next month (for cross-month Ramadan)
            // Only check if endDay is small, indicating cross-month
            if month == ramadan.month + 1 && ramadan.endDay <= 15 {
                return day <= ramadan.endDay
            }
        }
        
        return false
    }
    
    /// Gets the holiday type for a given date (if it is a holiday)
    func getHolidayType(_ date: Date) -> HolidayType? {
        if isEidHoliday(date) {
            return .eidHoliday
        } else if isNationalDay(date) {
            return .nationalDay
        } else if isFoundingDay(date) {
            return .foundingDay
        } else if isCompanyHoliday(date) {
            return .companyOff
        }
        return nil
    }
    
    /// Checks if a date is any type of holiday (public or company)
    func isHoliday(_ date: Date) -> Bool {
        return isPublicHoliday(date) || isCompanyHoliday(date)
    }
}

// MARK: - Holiday Type Enum

enum HolidayType {
    case eidHoliday
    case nationalDay
    case foundingDay
    case companyOff
}



