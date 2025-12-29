//
//  MizanFlowApp.swift
//  MizanFlow
//
//  Created by Bu Saad on 10/05/2025.
//

import SwiftUI

@main
struct MizanFlowApp: App {
    let dataService = DataPersistenceService.shared
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var scheduleViewModel = WorkScheduleViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasInitialized = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataService.context)
                .environmentObject(settingsViewModel)
                .environmentObject(scheduleViewModel)
                .preferredColorScheme(getPreferredColorScheme())
                .environment(\.layoutDirection, settingsViewModel.settings.language.layoutDirection)
                .safeAreaInset(edge: .top) {
                    // Add extra padding for the dynamic island
                    Color.clear.frame(height: 0)
                }
                .safeAreaInset(edge: .bottom) {
                    // Add extra padding for the home indicator
                    Color.clear.frame(height: 0)
                }
                .onChange(of: settingsViewModel.settings.theme) { oldValue, newValue in
                    // Only update if theme actually changed
                    if oldValue != newValue {
                        updateAppTheme()
                    }
                }
                .onChange(of: settingsViewModel.settings.language) { oldValue, newValue in
                    // Only update if language actually changed and we've initialized
                    if oldValue != newValue && hasInitialized {
                        updateAppLanguage()
                    }
                }
                .onAppear {
                    // Only initialize once
                    if !hasInitialized {
                        updateAppTheme()
                        updateAppLanguage()
                        hasInitialized = true
                    }
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // Only update theme on scene activation, language doesn't need to be updated
                updateAppTheme()
            } else if newPhase == .background {
                // Save all changes when app goes to background
                dataService.saveContext()
                scheduleViewModel.saveSchedule()
            }
        }
    }
    
    private func getPreferredColorScheme() -> ColorScheme? {
        switch settingsViewModel.settings.theme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
    
    private func updateAppTheme() {
        // Update app theme
        if settingsViewModel.settings.theme != .system {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                switch settingsViewModel.settings.theme {
                case .light:
                    window.overrideUserInterfaceStyle = .light
                case .dark:
                    window.overrideUserInterfaceStyle = .dark
                case .system:
                    window.overrideUserInterfaceStyle = .unspecified
                }
            }
        }
    }
    
    private func updateAppLanguage() {
        // Log language update
        #if DEBUG
        AppLogger.general.debug("Updating language to: \(settingsViewModel.settings.language.rawValue), Layout direction: \(settingsViewModel.settings.language.layoutDirection == .leftToRight ? "LTR" : "RTL")")
        #endif
        
        // Note: No need to manually call objectWillChange here
        // SwiftUI will automatically update when the @Published property changes
        // The layoutDirection environment value will update automatically via the .environment modifier
    }
}
