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
    
    // MARK: - Main Calculation
    
    /// Calculates salary breakdown for a given schedule and month
    /// - Parameters:
    ///   - schedule: The work schedule containing days with overtime hours
    ///   - baseSalary: The monthly base salary amount
    ///   - month: The month to calculate for
    /// - Returns: A SalaryBreakdown with calculated overtime and ADL hours
    func calculateSalary(for schedule: WorkSchedule, baseSalary: Double, month: Date) -> SalaryBreakdown {
        var breakdown = SalaryBreakdown(baseSalary: baseSalary, month: month)
        
        let cal = Calendar.current
        guard
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: month)),
            let monthEnd = cal.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)
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
        
        // Calculate totals
        var totalOvertimeHours: Double = 0.0
        var totalAdlHours: Double = 0.0
        
        for day in monthDays {
            totalOvertimeHours += day.overtimeHours ?? 0.0
            totalAdlHours += day.adlHours ?? 0.0
        }
        
        breakdown.overtimeHours = totalOvertimeHours
        breakdown.adlHours = totalAdlHours
        
        AppLogger.engine.info("Calculated salary: \(totalOvertimeHours) OT hours, \(totalAdlHours) ADL hours")
        
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
}
