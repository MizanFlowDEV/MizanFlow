import Foundation
import SwiftUI

class Settings: ObservableObject {
    @Published var language: Language {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            updateLocalization()
        }
    }
    
    @Published var theme: Theme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
        }
    }
    
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        }
    }
    
    @Published var lowOffDaysThreshold: Int {
        didSet {
            UserDefaults.standard.set(lowOffDaysThreshold, forKey: "lowOffDaysThreshold")
        }
    }
    
    public enum Language: String, CaseIterable {
        case english = "en"
        case arabic = "ar"
        
        var displayName: String {
            switch self {
            case .english: return "English"
            case .arabic: return "العربية"
            }
        }
        
        var layoutDirection: LayoutDirection {
            switch self {
            case .english: return .leftToRight
            case .arabic: return .rightToLeft
            }
        }
        
        var locale: Locale {
            return Locale(identifier: self.rawValue)
        }
    }
    
    public enum Theme: String, CaseIterable {
        case light
        case dark
        case system
        
        var displayName: String {
            switch self {
            case .light: return "Light"
            case .dark: return "Dark"
            case .system: return "System"
            }
        }
    }
    
    init() {
        self.language = Language(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "en") ?? .english
        self.theme = Theme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "system") ?? .system
        self.notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        self.lowOffDaysThreshold = UserDefaults.standard.integer(forKey: "lowOffDaysThreshold")
        if self.lowOffDaysThreshold == 0 {
            self.lowOffDaysThreshold = 3 // Default threshold
        }
        
        // Set initial localization
        updateLocalization()
    }
    
    private func updateLocalization() {
        // Update the app's locale
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        // Update date formatters
        let dateFormatter = DateFormatter()
        dateFormatter.locale = language.locale
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        // Update number formatters
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = language.locale
        numberFormatter.numberStyle = .decimal
        
        // Post notification for views to update
        NotificationCenter.default.post(name: NSNotification.Name("LanguageChanged"), object: nil)
    }
} 