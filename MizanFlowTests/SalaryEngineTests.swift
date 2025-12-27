import XCTest
@testable import MizanFlow

final class SalaryEngineTests: XCTestCase {
    
    var salaryEngine: SalaryEngine!
    
    override func setUp() {
        super.setUp()
        salaryEngine = SalaryEngine.shared
    }
    
    override func tearDown() {
        salaryEngine = nil
        super.tearDown()
    }
    
    func testCalculateSalary() {
        // Given
        let baseSalary = 10000.0
        let month = Date()
        var schedule = WorkSchedule(startDate: month)
        
        // Create some schedule days with overtime
        for i in 0..<14 {
            if let date = Calendar.current.date(byAdding: .day, value: i, to: month) {
                let day = WorkSchedule.ScheduleDay(
                    id: UUID(),
                    date: date,
                    type: .workday,
                    isHoliday: false,
                    isOverride: false,
                    notes: nil,
                    overtimeHours: 4.0,
                    adlHours: i == 0 || i == 13 ? 3.0 : 0.0,
                    isInHitch: true
                )
                schedule.days.append(day)
            }
        }
        
        // When
        let breakdown = salaryEngine.calculateSalary(for: schedule, baseSalary: baseSalary, month: month)
        
        // Then
        XCTAssertEqual(breakdown.baseSalary, baseSalary)
        XCTAssertGreaterThan(breakdown.overtimeHours, 0)
        XCTAssertGreaterThan(breakdown.adlHours, 0)
    }
    
    func testUpdateDeductionPercentages() {
        // Given
        var breakdown = SalaryBreakdown(baseSalary: 10000, month: Date())
        
        // When
        salaryEngine.updateDeductionPercentages(&breakdown, homeLoan: 25.0, espp: 5.0)
        
        // Then
        XCTAssertEqual(breakdown.homeLoanPercentage, 25.0)
        XCTAssertEqual(breakdown.esppPercentage, 5.0)
    }
    
    func testUpdateDeductionPercentagesClamping() {
        // Given
        var breakdown = SalaryBreakdown(baseSalary: 10000, month: Date())
        
        // When - test clamping
        salaryEngine.updateDeductionPercentages(&breakdown, homeLoan: 60.0, espp: 15.0)
        
        // Then - should be clamped to max values
        XCTAssertEqual(breakdown.homeLoanPercentage, 50.0) // Clamped to 50
        XCTAssertEqual(breakdown.esppPercentage, 10.0) // Clamped to 10
    }
    
    func testSpecialOperationsPercentage() {
        // Given
        var breakdown = SalaryBreakdown(baseSalary: 10000, month: Date())
        
        // When - valid percentage
        salaryEngine.updateSpecialOperationsPercentage(&breakdown, percentage: 7.0)
        
        // Then
        XCTAssertEqual(breakdown.specialOperationsPercentage, 7.0)
    }
    
    func testSpecialOperationsPercentageInvalid() {
        // Given
        var breakdown = SalaryBreakdown(baseSalary: 10000, month: Date())
        
        // When - invalid percentage
        salaryEngine.updateSpecialOperationsPercentage(&breakdown, percentage: 8.0)
        
        // Then - should default to 5%
        XCTAssertEqual(breakdown.specialOperationsPercentage, 5.0)
    }
    
    func testAddAdditionalIncome() {
        // Given
        var breakdown = SalaryBreakdown(baseSalary: 10000, month: Date())
        
        // When
        salaryEngine.addAdditionalIncome(&breakdown, description: "Bonus", amount: 1000.0, notes: "Q1 Bonus")
        
        // Then
        XCTAssertEqual(breakdown.additionalIncome.count, 1)
        XCTAssertEqual(breakdown.additionalIncome.first?.amount, 1000.0)
        XCTAssertEqual(breakdown.additionalIncome.first?.entryDescription, "Bonus")
    }
    
    func testAddCustomDeduction() {
        // Given
        var breakdown = SalaryBreakdown(baseSalary: 10000, month: Date())
        
        // When
        salaryEngine.addCustomDeduction(&breakdown, description: "Loan", amount: 500.0, notes: "Personal loan")
        
        // Then
        XCTAssertEqual(breakdown.customDeductions.count, 1)
        XCTAssertEqual(breakdown.customDeductions.first?.amount, 500.0)
        XCTAssertEqual(breakdown.customDeductions.first?.entryDescription, "Loan")
    }
    
    func testNetPayCalculation() {
        // Given
        var breakdown = SalaryBreakdown(baseSalary: 10000, month: Date())
        breakdown.overtimeHours = 20.0
        breakdown.adlHours = 6.0
        
        // When
        let netPay = salaryEngine.calculateNetPay(breakdown)
        
        // Then
        XCTAssertGreaterThan(netPay, 0)
        XCTAssertLessThan(netPay, breakdown.totalCompensation)
    }
}



