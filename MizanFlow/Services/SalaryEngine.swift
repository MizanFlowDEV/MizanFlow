import Foundation

class SalaryEngine {
    static let shared = SalaryEngine()
    private init() {}
    
    func calculateSalary(for schedule: WorkSchedule, baseSalary: Double, month: Date) -> SalaryBreakdown {
        var breakdown = SalaryBreakdown(baseSalary: baseSalary, month: month)
        
        let cal = Calendar.current
        guard
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: month)),
            let monthEnd = cal.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)
        else {
            return breakdown
        }
        
        let monthDays = schedule.days.filter {
            $0.date >= monthStart && $0.date <= monthEnd
        }
        
        var totalOvertimeHours: Double = 0.0
        var totalAdlHours: Double = 0.0
        
        for day in monthDays {
            totalOvertimeHours += day.overtimeHours ?? 0.0
            totalAdlHours += day.adlHours ?? 0.0
        }
        
        breakdown.overtimeHours = totalOvertimeHours
        breakdown.adlHours = totalAdlHours
        
        return breakdown
    }
    
    private func isHoliday(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: date)
        
        // Example holiday dates (should be moved to a configuration file)
        let holidays: [(month: Int, day: Int)] = [
            (1, 1),  // New Year's Day
            (9, 23), // National Day
            (2, 22), // Founding Day
            (4, 1),  // Eid Holiday
            (4, 2),  // Eid Holiday
            // Add more holidays as needed
        ]
        
        return holidays.contains { $0.month == components.month && $0.day == components.day }
    }
    
    func calculateNetPay(_ breakdown: SalaryBreakdown) -> Double {
        return breakdown.netPay
    }
    
    func calculateTotalDeductions(_ breakdown: SalaryBreakdown) -> Double {
        return breakdown.totalDeductions
    }
    
    func calculateTotalCompensation(_ breakdown: SalaryBreakdown) -> Double {
        return breakdown.totalCompensation
    }
    
    func addCustomDeduction(_ breakdown: inout SalaryBreakdown, description: String, amount: Double, notes: String? = nil) {
        let deduction = SalaryBreakdown.AdditionalEntry(
            id: UUID(),
            amount: amount,
            entryDescription: description,
            isIncome: false,
            notes: notes
        )
        breakdown.customDeductions.append(deduction)
    }
    
    func addAdditionalIncome(_ breakdown: inout SalaryBreakdown, description: String, amount: Double, notes: String? = nil) {
        let income = SalaryBreakdown.AdditionalEntry(
            id: UUID(),
            amount: amount,
            entryDescription: description,
            isIncome: true,
            notes: notes
        )
        breakdown.additionalIncome.append(income)
    }
    
    func updateDeductionPercentages(_ breakdown: inout SalaryBreakdown, homeLoan: Double, espp: Double) {
        breakdown.homeLoanPercentage = min(max(homeLoan, 0), 50) // Clamp between 0 and 50
        breakdown.esppPercentage = min(max(espp, 0), 10) // Clamp between 0 and 10
    }
    
    func updateSpecialOperationsPercentage(_ breakdown: inout SalaryBreakdown, percentage: Double) {
        // Only allow specific percentages
        switch percentage {
        case 5, 7, 10:
            breakdown.specialOperationsPercentage = percentage
        default:
            breakdown.specialOperationsPercentage = 5 // Default to 5%
        }
    }
} 
