import Foundation

struct SalaryBreakdown: Identifiable, Codable {
    var id: UUID
    var baseSalary: Double
    var month: Date
    var overtimeHours: Double
    var adlHours: Double
    var specialOperationsPercentage: Double // 5%, 7%, or 10%
    
    // Housing Allowance
    var housingAllowanceType: HousingAllowanceType = .fixed
    var housingAllowanceAmount: Double = 0 // For fixed type
    var housingAllowancePercentage: Double = 0 // For percentage type
    
    // Work days ratio for proration (0.0 to 1.0, default 1.0)
    var workDaysRatio: Double = 1.0
    
    // Allowances
    var remoteAllowance: Double {
        (baseSalary * 0.14) * workDaysRatio
    }
    
    var specialOperationsAllowance: Double {
        (baseSalary * (specialOperationsPercentage / 100)) * workDaysRatio
    }
    
    /// Housing Allowance: Paid once a year in December only
    /// Formula: max(3 × baseSalary, 40,000)
    /// No proration - it's a lump sum payment
    var housingAllowance: Double {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: self.month)
        
        // Only calculate if December (month 12)
        guard month == 12 else {
            return 0.0
        }
        
        // Formula: max(3 × baseSalary, 40,000)
        let threeTimesBase = baseSalary * 3.0
        return max(threeTimesBase, 40_000.0)
    }
    
    var transportationAllowance: Double = 1000 // Fixed 1000 SAR (no proration)
    
    // Deductions
    var homeLoanPercentage: Double // 25% to 50%
    var esppPercentage: Double // 1% to 10%
    
    var homeLoanDeduction: Double {
        baseSalary * (homeLoanPercentage / 100)
    }
    
    var esppDeduction: Double {
        baseSalary * (esppPercentage / 100)
    }
    
    var gosiDeduction: Double {
        baseSalary * 0.1125 // 11.25%
    }
    
    var sanidDeduction: Double {
        baseSalary * 0.0093 // 0.93%
    }
    
    // Additional Income & Deductions
    var additionalIncome: [AdditionalEntry]
    var customDeductions: [AdditionalEntry]
    
    // MARK: - Base Rate Calculations
    // Based on Saudi Aramco HR Manual: Standard Hourly Rate = Annual Base Salary ÷ 2,920 hours
    // Where 2,920 = 365 days × 8 hours (straight time annualized hours)
    
    /// Standard Hourly Rate calculated as (Annual Base Salary) ÷ 2,920 hours
    var standardHourlyRate: Double {
        (baseSalary * 12) / 2920
    }
    
    /// Overtime Premium Rate calculated as Standard Hourly Rate × 1.5 (150% premium)
    var overtimePremiumRate: Double {
        standardHourlyRate * 1.5
    }
    
    /// Straight Time Hourly Rate (same as Standard Hourly Rate, used for ADL calculations)
    var straightTimeHourlyRate: Double {
        standardHourlyRate
    }
    
    // MARK: - Payment Calculations
    
    /// Overtime Pay calculated as Overtime Hours × Overtime Premium Rate
    var overtimePay: Double {
        overtimeHours * overtimePremiumRate
    }
    
    /// Additional Straight Time (ADL) Pay calculated as ADL Hours × Straight Time Hourly Rate
    var adlPay: Double {
        adlHours * straightTimeHourlyRate
    }
    
    var totalAllowances: Double {
        remoteAllowance + specialOperationsAllowance + housingAllowance + transportationAllowance
    }
    
    var totalDeductions: Double {
        homeLoanDeduction + esppDeduction + gosiDeduction + sanidDeduction + customDeductions.reduce(0) { $0 + $1.amount }
    }
    
    var totalCompensation: Double {
        baseSalary + overtimePay + adlPay + totalAllowances + additionalIncome.reduce(0) { $0 + $1.amount }
    }
    
    var netPay: Double {
        totalCompensation - totalDeductions
    }
    
    // MARK: - Additional Entry Structure
    
    struct AdditionalEntry: Identifiable, Codable {
        var id: UUID
        var amount: Double
        var entryDescription: String
        var isIncome: Bool
        var notes: String?
    }
    
    // MARK: - Work Schedule Summary
    
    struct WorkScheduleSummary: Codable {
        var paidHours: Double // Work days × 8 hours
        var paidLeaveHours: Double // Leave/vacation days × 8 hours
        var straightTimeHours: Double // ADL hours
        var premiumHours: Double // Overtime hours
    }
    
    var workScheduleSummary: WorkScheduleSummary?
    
    init(baseSalary: Double, month: Date) {
        self.id = UUID()
        self.baseSalary = baseSalary
        self.month = month
        self.overtimeHours = 0
        self.adlHours = 0
        self.specialOperationsPercentage = 5
        self.homeLoanPercentage = 25
        self.esppPercentage = 1
        self.additionalIncome = []
        self.customDeductions = []
        self.housingAllowanceType = .fixed
        self.housingAllowanceAmount = 0
        self.housingAllowancePercentage = 0
        self.workDaysRatio = 1.0
        self.workScheduleSummary = nil
    }
    
    // CodingKeys for computed properties that shouldn't be encoded
    private enum CodingKeys: String, CodingKey {
        case id
        case baseSalary
        case month
        case overtimeHours
        case adlHours
        case specialOperationsPercentage
        case homeLoanPercentage
        case esppPercentage
        case additionalIncome
        case customDeductions
        case housingAllowanceType
        case housingAllowanceAmount
        case housingAllowancePercentage
        case workDaysRatio
        case workScheduleSummary
    }
}

// MARK: - Housing Allowance Type

enum HousingAllowanceType: String, Codable {
    case fixed
    case percentage
} 