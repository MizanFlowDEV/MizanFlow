import Foundation

struct SalaryBreakdown: Identifiable, Codable {
    var id: UUID
    var baseSalary: Double
    var month: Date
    var overtimeHours: Double
    var adlHours: Double
    var specialOperationsPercentage: Double // 5%, 7%, or 10%
    
    // Allowances
    var remoteAllowance: Double {
        baseSalary * 0.14
    }
    
    var specialOperationsAllowance: Double {
        baseSalary * (specialOperationsPercentage / 100)
    }
    
    var transportationAllowance: Double = 1000 // Fixed 1000 SAR
    
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
    
    // Calculations
    var overtimePay: Double {
        // Single overtime rate for all types
        return 0.00616438 * baseSalary * overtimeHours
    }
    
    var adlPay: Double {
        0.0041096 * baseSalary * adlHours
    }
    
    var totalAllowances: Double {
        remoteAllowance + specialOperationsAllowance + transportationAllowance
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
    }
} 