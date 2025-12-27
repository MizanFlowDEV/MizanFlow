import XCTest
@testable import MizanFlow

final class ValidationUtilitiesTests: XCTestCase {
    
    func testValidateSalary() {
        // Valid salary
        XCTAssertTrue(ValidationUtilities.validateSalary(10000).isValid)
        
        // Negative salary
        let negativeResult = ValidationUtilities.validateSalary(-1000)
        XCTAssertFalse(negativeResult.isValid)
        XCTAssertNotNil(negativeResult.errorMessage)
        
        // Very high salary (warning)
        let highResult = ValidationUtilities.validateSalary(2000000)
        XCTAssertFalse(highResult.isValid)
    }
    
    func testValidatePercentage() {
        // Valid percentage
        XCTAssertTrue(ValidationUtilities.validatePercentage(50.0, min: 0, max: 100).isValid)
        
        // Too low
        let lowResult = ValidationUtilities.validatePercentage(-5.0, min: 0, max: 100)
        XCTAssertFalse(lowResult.isValid)
        
        // Too high
        let highResult = ValidationUtilities.validatePercentage(150.0, min: 0, max: 100)
        XCTAssertFalse(highResult.isValid)
    }
    
    func testValidateHomeLoanPercentage() {
        // Valid
        XCTAssertTrue(ValidationUtilities.validateHomeLoanPercentage(25.0).isValid)
        
        // Too high
        XCTAssertFalse(ValidationUtilities.validateHomeLoanPercentage(60.0).isValid)
    }
    
    func testValidateESPPPercentage() {
        // Valid
        XCTAssertTrue(ValidationUtilities.validateESPPPercentage(5.0).isValid)
        
        // Too high
        XCTAssertFalse(ValidationUtilities.validateESPPPercentage(15.0).isValid)
    }
    
    func testValidateSpecialOperationsPercentage() {
        // Valid values
        XCTAssertTrue(ValidationUtilities.validateSpecialOperationsPercentage(5.0).isValid)
        XCTAssertTrue(ValidationUtilities.validateSpecialOperationsPercentage(7.0).isValid)
        XCTAssertTrue(ValidationUtilities.validateSpecialOperationsPercentage(10.0).isValid)
        
        // Invalid
        XCTAssertFalse(ValidationUtilities.validateSpecialOperationsPercentage(8.0).isValid)
    }
    
    func testValidateHours() {
        // Valid
        XCTAssertTrue(ValidationUtilities.validateHours(8.0).isValid)
        
        // Negative
        XCTAssertFalse(ValidationUtilities.validateHours(-1.0).isValid)
        
        // Too high
        XCTAssertFalse(ValidationUtilities.validateHours(25.0).isValid)
    }
    
    func testValidateDateRange() {
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start)!
        
        // Valid range
        XCTAssertTrue(ValidationUtilities.validateDateRange(start: start, end: end).isValid)
        
        // Invalid range (end before start)
        XCTAssertFalse(ValidationUtilities.validateDateRange(start: end, end: start).isValid)
    }
    
    func testValidateNonEmptyString() {
        // Valid
        XCTAssertTrue(ValidationUtilities.validateNonEmptyString("Test", fieldName: "Name").isValid)
        
        // Empty
        XCTAssertFalse(ValidationUtilities.validateNonEmptyString("", fieldName: "Name").isValid)
        
        // Whitespace only
        XCTAssertFalse(ValidationUtilities.validateNonEmptyString("   ", fieldName: "Name").isValid)
    }
    
    func testSanitizeString() {
        let input = "  Test String  "
        let output = ValidationUtilities.sanitizeString(input)
        XCTAssertEqual(output, "Test String")
    }
}



