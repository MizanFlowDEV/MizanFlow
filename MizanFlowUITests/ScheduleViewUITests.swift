import XCTest

final class ScheduleViewUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testScheduleViewLoads() throws {
        // Navigate to Schedule tab
        app.tabBars.buttons["Schedule"].tap()
        
        // Verify schedule view is displayed
        XCTAssertTrue(app.navigationBars["Schedule"].exists)
    }
    
    func testMonthNavigation() throws {
        // Navigate to Schedule tab
        app.tabBars.buttons["Schedule"].tap()
        
        // Tap next month button
        let nextButton = app.buttons.matching(identifier: "Next month").firstMatch
        if nextButton.exists {
            nextButton.tap()
        }
        
        // Verify view still exists (didn't crash)
        XCTAssertTrue(app.navigationBars["Schedule"].exists)
    }
    
    func testAccessibility() throws {
        // Navigate to Schedule tab
        app.tabBars.buttons["Schedule"].tap()
        
        // Verify accessibility elements exist
        let scheduleNavBar = app.navigationBars["Schedule"]
        XCTAssertTrue(scheduleNavBar.exists)
        
        // Test VoiceOver labels
        let scheduleButton = app.tabBars.buttons["Schedule"]
        XCTAssertTrue(scheduleButton.exists)
    }
    
    func testSalaryViewLoads() throws {
        // Navigate to Salary tab
        app.tabBars.buttons["Salary"].tap()
        
        // Verify salary view is displayed
        XCTAssertTrue(app.navigationBars["Salary"].exists)
    }
    
    func testBudgetViewLoads() throws {
        // Navigate to Budget tab
        app.tabBars.buttons["Budget"].tap()
        
        // Verify budget view is displayed
        XCTAssertTrue(app.navigationBars["Budget"].exists)
    }
    
    func testSettingsViewLoads() throws {
        // Navigate to Settings tab
        app.tabBars.buttons["Settings"].tap()
        
        // Verify settings view is displayed
        XCTAssertTrue(app.navigationBars["Settings"].exists)
    }
}



