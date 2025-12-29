import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var settings: Settings
    @Published var showingLanguageSheet = false
    @Published var showingThemeSheet = false
    @Published var showingLanguageRestartAlert = false
    @Published var showingCacheWipeAlert = false
    
    private let dataService = DataPersistenceService.shared
    
    init() {
        self.settings = Settings()
    }
    
    func updateLanguage(_ language: Settings.Language) {
        // Only update if language actually changed
        guard settings.language != language else { return }
        
        settings.language = language
        updateLayoutDirection()
        
        // Show SwiftUI alert to confirm restart
        showingLanguageRestartAlert = true
        // Note: No need to manually call objectWillChange or post notification
        // The @Published property will automatically trigger updates
        // Settings.updateLocalization() already posts the notification
    }
    
    func updateTheme(_ theme: Settings.Theme) {
        // Only update if theme actually changed
        guard settings.theme != theme else { return }
        
        settings.theme = theme
        // Note: No need to manually call objectWillChange
        // The @Published property will automatically trigger updates
    }
    
    func toggleNotifications() {
        settings.notificationsEnabled.toggle()
        if settings.notificationsEnabled {
            SmartAlertService.shared.requestNotificationPermission()
        }
    }
    
    func updateLowOffDaysThreshold(_ threshold: Int) {
        settings.lowOffDaysThreshold = threshold
    }
    
    private func updateLayoutDirection() {
        // Layout direction is handled automatically by SwiftUI's environment modifier
        // No action needed here - the .environment(\.layoutDirection) in MizanFlowApp
        // will automatically update when settings.language changes
        #if DEBUG
        AppLogger.viewModel.debug("Layout direction updated to: \(self.settings.language.layoutDirection == .leftToRight ? "LTR" : "RTL")")
        #endif
    }
    
    // MARK: - Formatting Methods
    
    func getLanguageDisplayName(_ language: Settings.Language) -> String {
        language.displayName
    }
    
    func getThemeDisplayName(_ theme: Settings.Theme) -> String {
        theme.displayName
    }
    
    func formatDate(_ date: Date) -> String {
        return FormattingUtilities.formatExportDate(date)
    }
    
    // MARK: - Validation Methods
    
    func isValidThreshold(_ threshold: Int) -> Bool {
        threshold >= 1 && threshold <= 14
    }
    
    // MARK: - App Info
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var copyrightYear: String {
        let calendar = Calendar.current
        return String(calendar.component(.year, from: Date()))
    }
    
    // MARK: - Export Methods
    
    func prepareExportData() -> Data? {
        let exportSettings = ExportSettings(
            language: settings.language.rawValue,
            theme: settings.theme.rawValue,
            notificationsEnabled: settings.notificationsEnabled,
            lowOffDaysThreshold: settings.lowOffDaysThreshold,
            appVersion: appVersion,
            buildNumber: buildNumber,
            exportDate: Date()
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(exportSettings)
        } catch {
            AppLogger.viewModel.error("Failed to encode settings: \(error.localizedDescription)")
            return nil
        }
    }
    
    func getThemeColor() -> Color {
        switch settings.theme {
        case .light:
            return Color.blue
        case .dark:
            return Color.orange
        case .system:
            return Color.accentColor
        }
    }
}

// MARK: - Export Types

struct ExportSettings: Codable {
    let language: String
    let theme: String
    let notificationsEnabled: Bool
    let lowOffDaysThreshold: Int
    let appVersion: String
    let buildNumber: String
    let exportDate: Date
} 