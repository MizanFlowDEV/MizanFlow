import Foundation

/// SalaryEngine handles all salary-related calculations for the MizanFlow app.
/// It processes work schedules, calculates overtime, allowances, and deductions.
class SalaryEngine {
    static let shared = SalaryEngine()
    private init() {}
    
    // MARK: - Date Utilities
    
    /// Normalizes a date to the start of day for accurate date comparisons
    private func normalizeToStartOfDay(_ date: Date) -> Date {
        return Calendar.current.startOfDay(for: date)
    }
    
    /// Calculates work days ratio for proration based on vacation days
    /// Per HR Manual: Allowances are NOT paid during Vacation Leave ("L" Time)
    /// - Parameters:
    ///   - schedule: The work schedule
    ///   - month: The month to calculate for
    /// - Returns: Ratio of work days (0.0 to 1.0), where 1.0 = full month with no vacation
    func calculateWorkDaysRatio(for schedule: WorkSchedule, month: Date) -> Double {
        let cal = Calendar.current
        guard
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: month)),
            let dayRange = cal.range(of: .day, in: .month, for: monthStart)
        else {
            AppLogger.engine.warning("Failed to calculate month boundaries for work days ratio")
            return 1.0 // Default to full ratio if calculation fails
        }
        
        let totalDaysInMonth = dayRange.count
        let normalizedMonthStart = normalizeToStartOfDay(monthStart)
        let normalizedMonthEnd = normalizeToStartOfDay(cal.date(byAdding: DateComponents(day: totalDaysInMonth - 1), to: monthStart) ?? monthStart)
        
        // Filter schedule days for the selected month
        let monthDays = schedule.days.filter { day in
            let normalizedDayDate = normalizeToStartOfDay(day.date)
            return normalizedDayDate >= normalizedMonthStart && normalizedDayDate <= normalizedMonthEnd
        }
        
        // Count vacation days (type == .vacation)
        let vacationDays = monthDays.filter { $0.type == .vacation }.count
        
        // Calculate ratio: (Total Days - Vacation Days) / Total Days
        let workDays = totalDaysInMonth - vacationDays
        let ratio = totalDaysInMonth > 0 ? Double(workDays) / Double(totalDaysInMonth) : 1.0
        
        AppLogger.engine.debug("Work days ratio calculated: totalDays=\(totalDaysInMonth), vacationDays=\(vacationDays), workDays=\(workDays), ratio=\(ratio)")
        
        return max(0.0, min(1.0, ratio)) // Clamp between 0.0 and 1.0
    }
    
    // MARK: - Main Calculation
    
    /// Calculates salary breakdown for a given schedule and month
    /// - Parameters:
    ///   - schedule: The work schedule containing days with overtime hours
    ///   - baseSalary: The monthly base salary amount
    ///   - month: The month to calculate for
    /// - Returns: A SalaryBreakdown with calculated overtime and ADL hours
    func calculateSalary(for schedule: WorkSchedule, baseSalary: Double, month: Date) -> SalaryBreakdown {
        var breakdown = SalaryBreakdown(baseSalary: baseSalary, month: month)
        
        // Validate input: baseSalary must be non-negative
        guard baseSalary >= 0 else {
            AppLogger.engine.error("Invalid base salary: \(baseSalary). Must be non-negative.")
            return breakdown
        }
        
        let cal = Calendar.current
        // Use Calendar.range to get accurate month boundaries, handling all edge cases including leap years
        guard
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: month)),
            let dayRange = cal.range(of: .day, in: .month, for: monthStart),
            let monthEnd = cal.date(byAdding: DateComponents(day: dayRange.count - 1), to: monthStart)
        else {
            AppLogger.engine.warning("Failed to calculate month boundaries for salary calculation")
            return breakdown
        }
        
        // Normalize dates to start of day for accurate comparison
        let normalizedMonthStart = normalizeToStartOfDay(monthStart)
        let normalizedMonthEnd = normalizeToStartOfDay(monthEnd)
        
        // Filter schedule days for the selected month
        let monthDays = schedule.days.filter { day in
            let normalizedDayDate = normalizeToStartOfDay(day.date)
            return normalizedDayDate >= normalizedMonthStart && normalizedDayDate <= normalizedMonthEnd
        }
        
        // Validate that schedule has days for this month
        if monthDays.isEmpty {
            AppLogger.engine.warning("No schedule days found for month \(month.formatted(date: .abbreviated, time: .omitted)). Schedule may need to be generated.")
        }
        
        // Calculate totals - trust what the schedule view shows
        // The schedule is the source of truth: if it shows vacation/off, don't count it
        // If it shows workday, count the overtime/ADL hours that are already stored in the schedule
        var totalOvertimeHours: Double = 0.0
        var totalAdlHours: Double = 0.0
        
        AppLogger.engine.debug("Starting salary calculation: month=\(month.formatted(date: .abbreviated, time: .omitted)), monthDaysCount=\(monthDays.count), scheduleIsInterrupted=\(schedule.isInterrupted), interruptionType=\(schedule.interruptionType?.rawValue ?? "nil")")
        
        for day in monthDays {
            // Only count overtime from actual work day types
            // Vacation, training, companyOff, and earnedOffDay are explicitly excluded
            // This matches exactly what the schedule view displays
            let isWorkDayType = (day.type == .workday || day.type == .eidHoliday || 
                                day.type == .nationalDay || day.type == .foundingDay)
            
            let dayOvertime = day.overtimeHours ?? 0.0
            let dayAdl = day.adlHours ?? 0.0
            
            AppLogger.engine.debug("Processing day: date=\(day.date.formatted(date: .numeric, time: .omitted)), type=\(day.type.rawValue), overtimeHours=\(dayOvertime), adlHours=\(dayAdl), isWorkDayType=\(isWorkDayType), isOverride=\(day.isOverride), isInHitch=\(day.isInHitch)")
            
            if isWorkDayType {
                // Trust the overtime/ADL hours stored in the schedule
                // The schedule generation/recalculation should have already set these correctly
                // based on interruptions, day types, etc.
                totalOvertimeHours += dayOvertime
                totalAdlHours += dayAdl
                
                AppLogger.engine.debug("Day counted for salary: date=\(day.date.formatted(date: .numeric, time: .omitted)), overtimeAdded=\(dayOvertime), adlAdded=\(dayAdl), runningTotalOT=\(totalOvertimeHours), runningTotalADL=\(totalAdlHours)")
            } else {
                AppLogger.engine.debug("Day excluded from salary: date=\(day.date.formatted(date: .numeric, time: .omitted)), type=\(day.type.rawValue), overtimeHours=\(dayOvertime), adlHours=\(dayAdl)")
            }
            // All other day types (vacation, training, companyOff, earnedOffDay, etc.) are excluded
        }
        
        breakdown.overtimeHours = totalOvertimeHours
        breakdown.adlHours = totalAdlHours
        
        // Calculate work days ratio for allowance proration
        breakdown.workDaysRatio = calculateWorkDaysRatio(for: schedule, month: month)
        
        // Calculate work schedule summary
        breakdown.workScheduleSummary = calculateWorkScheduleSummary(for: schedule, month: month)
        
        AppLogger.engine.debug("Salary calculation complete: totalOvertimeHours=\(totalOvertimeHours), totalAdlHours=\(totalAdlHours), workDaysRatio=\(breakdown.workDaysRatio)")
        
        AppLogger.engine.info("Calculated salary: \(totalOvertimeHours) OT hours, \(totalAdlHours) ADL hours, workDaysRatio=\(breakdown.workDaysRatio)")
        
        return breakdown
    }
    
    // MARK: - Deduction Management
    
    /// Updates deduction percentages with validation
    /// - Parameters:
    ///   - breakdown: The salary breakdown to update
    ///   - homeLoan: Home loan percentage (0-50)
    ///   - espp: ESPP percentage (0-10)
    func updateDeductionPercentages(_ breakdown: inout SalaryBreakdown, homeLoan: Double, espp: Double) {
        breakdown.homeLoanPercentage = min(max(homeLoan, 0), 50) // Clamp between 0 and 50
        breakdown.esppPercentage = min(max(espp, 0), 10) // Clamp between 0 and 10
    }
    
    /// Updates special operations percentage with validation
    /// - Parameters:
    ///   - breakdown: The salary breakdown to update
    ///   - percentage: Special operations percentage (5%, 7%, or 10%)
    func updateSpecialOperationsPercentage(_ breakdown: inout SalaryBreakdown, percentage: Double) {
        // Only allow specific percentages
        switch percentage {
        case 5, 7, 10:
            breakdown.specialOperationsPercentage = percentage
        default:
            breakdown.specialOperationsPercentage = 5 // Default to 5%
            AppLogger.engine.warning("Invalid special operations percentage: \(percentage), defaulting to 5%")
        }
    }
    
    // MARK: - Additional Entries
    
    /// Adds a custom deduction to the salary breakdown
    /// - Parameters:
    ///   - breakdown: The salary breakdown to update
    ///   - description: Description of the deduction
    ///   - amount: Amount of the deduction
    ///   - notes: Optional notes
    func addCustomDeduction(_ breakdown: inout SalaryBreakdown, description: String, amount: Double, notes: String? = nil) {
        let deduction = SalaryBreakdown.AdditionalEntry(
            id: UUID(),
            amount: amount,
            entryDescription: description,
            isIncome: false,
            notes: notes
        )
        breakdown.customDeductions.append(deduction)
        AppLogger.engine.info("Added custom deduction: \(description) - \(amount)")
    }
    
    /// Adds additional income to the salary breakdown
    /// - Parameters:
    ///   - breakdown: The salary breakdown to update
    ///   - description: Description of the income
    ///   - amount: Amount of the income
    ///   - notes: Optional notes
    func addAdditionalIncome(_ breakdown: inout SalaryBreakdown, description: String, amount: Double, notes: String? = nil) {
        let income = SalaryBreakdown.AdditionalEntry(
            id: UUID(),
            amount: amount,
            entryDescription: description,
            isIncome: true,
            notes: notes
        )
        breakdown.additionalIncome.append(income)
        AppLogger.engine.info("Added additional income: \(description) - \(amount)")
    }
    
    // MARK: - Rate Calculation Helpers
    
    /// Calculates Standard Hourly Rate based on Saudi Aramco HR Manual policy
    /// Formula: (Annual Base Salary) ÷ 2,920 hours
    /// Where 2,920 = 365 days × 8 hours (straight time annualized hours)
    /// - Parameter baseSalary: Monthly base salary amount
    /// - Returns: Standard hourly rate
    func calculateStandardHourlyRate(baseSalary: Double) -> Double {
        return (baseSalary * 12) / 2920
    }
    
    /// Calculates Overtime Premium Rate (150% of standard hourly rate)
    /// Formula: Standard Hourly Rate × 1.5
    /// - Parameter baseSalary: Monthly base salary amount
    /// - Returns: Overtime premium hourly rate
    func calculateOvertimePremiumRate(baseSalary: Double) -> Double {
        return calculateStandardHourlyRate(baseSalary: baseSalary) * 1.5
    }
    
    /// Calculates Straight Time Hourly Rate (same as Standard Hourly Rate)
    /// Used for ADL and other straight time payments
    /// - Parameter baseSalary: Monthly base salary amount
    /// - Returns: Straight time hourly rate
    func calculateStraightTimeHourlyRate(baseSalary: Double) -> Double {
        return calculateStandardHourlyRate(baseSalary: baseSalary)
    }
    
    // MARK: - Calculation Helpers
    
    /// Calculates net pay from a salary breakdown
    /// - Parameter breakdown: The salary breakdown
    /// - Returns: Net pay amount
    func calculateNetPay(_ breakdown: SalaryBreakdown) -> Double {
        return breakdown.netPay
    }
    
    /// Calculates total deductions from a salary breakdown
    /// - Parameter breakdown: The salary breakdown
    /// - Returns: Total deductions amount
    func calculateTotalDeductions(_ breakdown: SalaryBreakdown) -> Double {
        return breakdown.totalDeductions
    }
    
    /// Calculates total compensation from a salary breakdown
    /// - Parameter breakdown: The salary breakdown
    /// - Returns: Total compensation amount
    func calculateTotalCompensation(_ breakdown: SalaryBreakdown) -> Double {
        return breakdown.totalCompensation
    }
    
    // MARK: - Work Schedule Summary
    
    /// Calculates work schedule summary metrics for a given month
    /// - Parameters:
    ///   - schedule: The work schedule
    ///   - month: The month to calculate for
    /// - Returns: WorkScheduleSummary with paid hours, leave hours, straight time, and premium hours
    func calculateWorkScheduleSummary(for schedule: WorkSchedule, month: Date) -> SalaryBreakdown.WorkScheduleSummary {
        // #region agent log
        do {
            let logData: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "A",
                "location": "SalaryEngine.swift:269",
                "message": "calculateWorkScheduleSummary entry",
                "data": [
                    "month": month.description,
                    "scheduleDaysCount": schedule.days.count
                ],
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: logData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                let logPath = "/Users/busaad/AppDev/MizanFlow/.cursor/debug.log"
                if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write((jsonString + "\n").data(using: .utf8)!)
                    fileHandle.closeFile()
                } else {
                    try? jsonString.write(toFile: logPath, atomically: false, encoding: .utf8)
                }
            }
        }
        // #endregion
        
        let cal = Calendar.current
        guard
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: month)),
            let dayRange = cal.range(of: .day, in: .month, for: monthStart),
            let monthEnd = cal.date(byAdding: DateComponents(day: dayRange.count - 1), to: monthStart)
        else {
            AppLogger.engine.warning("Failed to calculate month boundaries for work schedule summary")
            return SalaryBreakdown.WorkScheduleSummary(paidHours: 0, paidLeaveHours: 0, straightTimeHours: 0, premiumHours: 0)
        }
        
        let normalizedMonthStart = normalizeToStartOfDay(monthStart)
        let normalizedMonthEnd = normalizeToStartOfDay(monthEnd)
        
        // Filter schedule days for the selected month
        let monthDays = schedule.days.filter { day in
            let normalizedDayDate = normalizeToStartOfDay(day.date)
            return normalizedDayDate >= normalizedMonthStart && normalizedDayDate <= normalizedMonthEnd
        }
        
        // #region agent log
        do {
            let logData: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "E",
                "location": "SalaryEngine.swift:287",
                "message": "Month filtering result",
                "data": [
                    "totalDaysInMonth": dayRange.count,
                    "monthDaysCount": monthDays.count,
                    "monthStart": monthStart.description,
                    "monthEnd": monthEnd.description
                ],
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: logData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                let logPath = "/Users/busaad/AppDev/MizanFlow/.cursor/debug.log"
                if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write((jsonString + "\n").data(using: .utf8)!)
                    fileHandle.closeFile()
                } else {
                    try? jsonString.write(toFile: logPath, atomically: false, encoding: .utf8)
                }
            }
        }
        // #endregion
        
        // Count work days (type == .workday, .eidHoliday, .nationalDay, .foundingDay)
        let workDays = monthDays.filter { day in
            day.type == .workday || day.type == .eidHoliday || day.type == .nationalDay || day.type == .foundingDay
        }.count
        
        // Count earned off days
        let earnedOffDays = monthDays.filter { $0.type == .earnedOffDay }.count
        
        // Count all paid days (work + earned off + holidays, excluding vacation)
        let allPaidDays = monthDays.filter { day in
            day.type != .vacation && day.type != .training && day.type != .companyOff
        }.count
        
        // Count leave/vacation days (type == .vacation)
        let leaveDays = monthDays.filter { $0.type == .vacation }.count
        
        // #region agent log
        do {
            let logData: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "A",
                "location": "SalaryEngine.swift:300",
                "message": "Day type counts BEFORE calculation",
                "data": [
                    "workDays": workDays,
                    "earnedOffDays": earnedOffDays,
                    "allPaidDays": allPaidDays,
                    "leaveDays": leaveDays,
                    "totalDaysInMonth": dayRange.count
                ],
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: logData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                let logPath = "/Users/busaad/AppDev/MizanFlow/.cursor/debug.log"
                if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write((jsonString + "\n").data(using: .utf8)!)
                    fileHandle.closeFile()
                } else {
                    try? jsonString.write(toFile: logPath, atomically: false, encoding: .utf8)
                }
            }
        }
        // #endregion
        
        // Calculate paid hours: ALL days in month × 8 hours (per statement: 240.0 = 30 days × 8)
        // This includes work days, earned off days, holidays, etc. - all calendar days
        let paidHours = Double(dayRange.count) * 8.0
        
        // Calculate paid leave hours (leave days × 8 hours)
        let paidLeaveHours = Double(leaveDays) * 8.0
        
        // Calculate straight time hours (ADL hours from ALL days in month, including earned off days)
        // Per time sheet: Nov 16 (earned off day) has 8.00 ADL hours
        let straightTimeHours = monthDays.reduce(0.0) { total, day in
            total + (day.adlHours ?? 0.0)
        }
        
        // Calculate premium hours (overtime hours from schedule)
        let premiumHours = monthDays.reduce(0.0) { total, day in
            total + (day.overtimeHours ?? 0.0)
        }
        
        // #region agent log
        do {
            var dayBreakdown: [[String: Any]] = []
            for day in monthDays {
                dayBreakdown.append([
                    "date": day.date.description,
                    "type": day.type.rawValue,
                    "adlHours": day.adlHours ?? 0.0,
                    "overtimeHours": day.overtimeHours ?? 0.0
                ])
            }
            let logData: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "D",
                "location": "SalaryEngine.swift:340",
                "message": "ADL hours breakdown (all days)",
                "data": [
                    "dayBreakdown": dayBreakdown,
                    "straightTimeHours": straightTimeHours
                ],
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: logData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                let logPath = "/Users/busaad/AppDev/MizanFlow/.cursor/debug.log"
                if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write((jsonString + "\n").data(using: .utf8)!)
                    fileHandle.closeFile()
                } else {
                    try? jsonString.write(toFile: logPath, atomically: false, encoding: .utf8)
                }
            }
        }
        // #endregion
        
        AppLogger.engine.debug("Work schedule summary: paidHours=\(paidHours), paidLeaveHours=\(paidLeaveHours), straightTimeHours=\(straightTimeHours), premiumHours=\(premiumHours)")
        
        // #region agent log
        do {
            let logData: [String: Any] = [
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "ALL",
                "location": "SalaryEngine.swift:390",
                "message": "calculateWorkScheduleSummary exit",
                "data": [
                    "paidHours": paidHours,
                    "paidLeaveHours": paidLeaveHours,
                    "straightTimeHours": straightTimeHours,
                    "premiumHours": premiumHours
                ],
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: logData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                let logPath = "/Users/busaad/AppDev/MizanFlow/.cursor/debug.log"
                if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write((jsonString + "\n").data(using: .utf8)!)
                    fileHandle.closeFile()
                } else {
                    try? jsonString.write(toFile: logPath, atomically: false, encoding: .utf8)
                }
            }
        }
        // #endregion
        
        return SalaryBreakdown.WorkScheduleSummary(
            paidHours: paidHours,
            paidLeaveHours: paidLeaveHours,
            straightTimeHours: straightTimeHours,
            premiumHours: premiumHours
        )
    }
    
    // MARK: - Housing Allowance Management
    
    /// Updates housing allowance with validation
    /// - Parameters:
    ///   - breakdown: The salary breakdown to update
    ///   - type: Housing allowance type (fixed or percentage)
    ///   - amount: Fixed amount (if type is .fixed)
    ///   - percentage: Percentage of base salary (if type is .percentage)
    /// Note: Housing allowance is now auto-calculated (max(3 × baseSalary, 40,000) in December only)
    /// This method is kept for backward compatibility but is no longer used.
    func updateHousingAllowance(_ breakdown: inout SalaryBreakdown, type: HousingAllowanceType, amount: Double? = nil, percentage: Double? = nil) {
        breakdown.housingAllowanceType = type
        
        switch type {
        case .fixed:
            if let amount = amount {
                let finalAmount = max(0, amount)
                breakdown.housingAllowanceAmount = finalAmount
                AppLogger.engine.info("Updated housing allowance: fixed amount = \(finalAmount)")
            }
        case .percentage:
            if let percentage = percentage {
                let finalPercentage = max(0, min(100, percentage)) // Clamp between 0 and 100
                breakdown.housingAllowancePercentage = finalPercentage
                AppLogger.engine.info("Updated housing allowance: percentage = \(finalPercentage)%")
            }
        }
    }
}
