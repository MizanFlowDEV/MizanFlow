import UIKit

/// Utility for haptic feedback throughout the app
struct HapticFeedback {
    
    // MARK: - Feedback Types
    
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    // MARK: - Contextual Feedback
    
    static func buttonTap() {
        light()
    }
    
    static func saveSuccess() {
        success()
    }
    
    static func saveError() {
        error()
    }
    
    static func deleteAction() {
        medium()
    }
    
    static func calendarNavigation() {
        selection()
    }
    
    static func dateSelection() {
        light()
    }
}



