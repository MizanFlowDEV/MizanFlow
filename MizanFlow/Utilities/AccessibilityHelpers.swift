import SwiftUI

/// Accessibility helpers and utilities
struct AccessibilityHelpers {
    
    // MARK: - Common Accessibility Labels
    
    static func buttonLabel(_ action: String) -> String {
        return NSLocalizedString("\(action) button", comment: "Button accessibility label")
    }
    
    static func tabLabel(_ tabName: String) -> String {
        return NSLocalizedString("\(tabName) tab", comment: "Tab accessibility label")
    }
    
    static func calendarDayLabel(_ day: Int, _ month: String) -> String {
        return NSLocalizedString("Day \(day) of \(month)", comment: "Calendar day accessibility")
    }
    
    static func scheduleDayLabel(_ type: String) -> String {
        return NSLocalizedString("Schedule day type: \(type)", comment: "Schedule day type accessibility")
    }
    
    // MARK: - View Modifiers
    
    static func accessibilityModifier(for view: some View) -> some View {
        view
            .accessibilityElement(children: .combine)
    }
}

/// Accessibility view modifier extensions
extension View {
    /// Adds standard accessibility support for interactive elements
    func accessibilityInteractive(_ label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
    
    /// Adds accessibility support for calendar cells
    func accessibilityCalendarCell(day: Int, type: String, isSelected: Bool = false) -> some View {
        self
            .accessibilityLabel("\(day), \(type)")
            .accessibilityValue(isSelected ? NSLocalizedString("Selected", comment: "Selected state") : "")
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
    
    /// Adds accessibility support for form fields
    func accessibilityFormField(label: String, value: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityHint(hint ?? "")
    }
}



