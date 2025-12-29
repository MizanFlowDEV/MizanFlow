import SwiftUI
import UniformTypeIdentifiers
import CoreData
import os

struct SettingsView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingExportSheet = false
    @State private var exportData: Data?
    @ObservedObject var scheduleViewModel: WorkScheduleViewModel
    @State private var showResetAlert = false
    @FocusState private var isThresholdFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            List {
                // Language Section
                Section(header: HStack {
                    Image(systemName: "globe")
                        .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                    Text("Language")
                        .font(DesignTokens.Typography.sectionTitle)
                }) {
                    Button(action: {
                        // Add haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        viewModel.showingLanguageSheet = true
                    }) {
                        HStack {
                            Text("Language")
                                .font(DesignTokens.Typography.body)
                            Spacer()
                            Text(viewModel.getLanguageDisplayName(viewModel.settings.language))
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(DesignTokens.Color.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: DesignTokens.Icon.small, weight: DesignTokens.Icon.weight))
                                .foregroundColor(DesignTokens.Color.textSecondary)
                        }
                        .frame(minHeight: DesignTokens.Calendar.minCellSize)
                    }
                    .accessibilityLabel("Language")
                    .accessibilityHint("Tap to change the app language")
                }
                
                // Theme Section
                Section(header: HStack {
                    Image(systemName: "paintbrush")
                        .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                    Text("Theme")
                        .font(DesignTokens.Typography.sectionTitle)
                }) {
                    Button(action: {
                        // Add haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        viewModel.showingThemeSheet = true
                    }) {
                        HStack {
                            Text("Theme")
                                .font(DesignTokens.Typography.body)
                            Spacer()
                            Text(viewModel.getThemeDisplayName(viewModel.settings.theme))
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(DesignTokens.Color.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: DesignTokens.Icon.small, weight: DesignTokens.Icon.weight))
                                .foregroundColor(DesignTokens.Color.textSecondary)
                        }
                        .frame(minHeight: DesignTokens.Calendar.minCellSize)
                    }
                    .accessibilityLabel("Theme")
                    .accessibilityHint("Tap to change the app theme")
                }
                
                // Notifications Section
                Section(header: HStack {
                    Image(systemName: "bell")
                        .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                    Text("Notifications")
                        .font(DesignTokens.Typography.sectionTitle)
                }) {
                    Toggle("Enable Notifications", isOn: $viewModel.settings.notificationsEnabled)
                        .frame(minHeight: DesignTokens.Calendar.minCellSize)
                        .accessibilityLabel("Enable Notifications")
                        .accessibilityHint("Toggle to enable or disable app notifications")
                    
                    if viewModel.settings.notificationsEnabled {
                        HStack {
                            Text("Low Off Days Threshold")
                                .font(DesignTokens.Typography.body)
                            Spacer()
                            TextField("Days", value: $viewModel.settings.lowOffDaysThreshold, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                                .focused($isThresholdFieldFocused)
                                .font(DesignTokens.Typography.body)
                        }
                        .frame(minHeight: DesignTokens.Calendar.minCellSize)
                        .accessibilityLabel("Low Off Days Threshold")
                        .accessibilityHint("Enter the number of off days that triggers a low balance warning")
                    }
                }
                
                // About Section
                Section(header: HStack {
                    Image(systemName: "info.circle")
                        .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                    Text("About")
                        .font(DesignTokens.Typography.sectionTitle)
                }) {
                    HStack {
                        Image(systemName: "app.badge")
                            .foregroundColor(DesignTokens.Color.primary)
                            .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                        Text("Version")
                            .font(DesignTokens.Typography.body)
                        Spacer()
                        Text(viewModel.appVersion)
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Color.textSecondary)
                    }
                    .frame(minHeight: DesignTokens.Calendar.minCellSize)
                    
                    HStack {
                        Image(systemName: "hammer")
                            .foregroundColor(DesignTokens.Color.textSecondary)
                            .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                        Text("Build")
                            .font(DesignTokens.Typography.body)
                        Spacer()
                        Text(viewModel.buildNumber)
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Color.textSecondary)
                    }
                    .frame(minHeight: DesignTokens.Calendar.minCellSize)
                    
                    HStack {
                        Image(systemName: "c.circle")
                            .foregroundColor(DesignTokens.Color.textSecondary)
                            .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                        Text("Copyright")
                            .font(DesignTokens.Typography.body)
                        Spacer()
                        Text("© \(viewModel.copyrightYear) MizanFlow")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Color.textSecondary)
                    }
                    .frame(minHeight: DesignTokens.Calendar.minCellSize)
                }
                
                // Export Section
                Section(header: HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                    Text("Data Management")
                        .font(DesignTokens.Typography.sectionTitle)
                }) {
                    Button(action: {
                        // Add haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        exportData = viewModel.prepareExportData()
                        showingExportSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                            Text("Export Settings")
                                .font(DesignTokens.Typography.body)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: DesignTokens.Icon.small, weight: DesignTokens.Icon.weight))
                                .foregroundColor(DesignTokens.Color.textSecondary)
                        }
                        .frame(minHeight: DesignTokens.Calendar.minCellSize)
                    }
                    .accessibilityLabel("Export Settings")
                    .accessibilityHint("Tap to export your app settings and data")
                }
                
                // Testing Section
                Section(header: HStack {
                    Image(systemName: "testtube.2")
                        .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                    Text("Testing")
                        .font(DesignTokens.Typography.sectionTitle)
                }) {
                    Button(action: {
                        // Add haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        showResetAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(DesignTokens.Color.error)
                                .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                            Text("Reset Vacation Balance to 30 Days")
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(DesignTokens.Color.error)
                        }
                        .frame(minHeight: DesignTokens.Calendar.minCellSize)
                    }
                    .accessibilityLabel("Reset Vacation Balance to 30 Days")
                    .accessibilityHint("Tap to reset vacation balance for testing purposes")
                    .alert(isPresented: $showResetAlert) {
                        Alert(
                            title: Text("Reset Vacation Balance"),
                            message: Text("Are you sure you want to reset the vacation balance to 30 days? This is for testing only."),
                            primaryButton: .destructive(Text("Reset")) {
                                scheduleViewModel.setVacationBalance(30)
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
                
                // Data Management Section - Clear Data
                Section {
                    Button(action: {
                        // Add haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                        impactFeedback.impactOccurred()
                        viewModel.showingCacheWipeAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(DesignTokens.Color.error)
                                .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                            Text("Clear All Data")
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(DesignTokens.Color.error)
                            Spacer()
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(DesignTokens.Color.error)
                                .font(.system(size: DesignTokens.Icon.small, weight: DesignTokens.Icon.weight))
                        }
                        .frame(minHeight: DesignTokens.Calendar.minCellSize)
                    }
                    .accessibilityLabel("Clear All Data")
                    .accessibilityHint("Warning: This will permanently delete all your data. Tap to confirm.")
                    .alert(isPresented: $viewModel.showingCacheWipeAlert) {
                        Alert(
                            title: Text("Clear All Data"),
                            message: Text("Are you sure you want to clear all data? This action cannot be undone."),
                            primaryButton: .destructive(Text("Clear")) {
                                // First reset the ViewModel state
                                scheduleViewModel.reset()
                                // Then wipe all CoreData through DataPersistenceService
                                let context = DataPersistenceService.shared.context
                                let model = DataPersistenceService.shared.persistentContainer.managedObjectModel
                                
                                for entity in model.entities {
                                    guard let entityName = entity.name else { continue }
                                    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                                    let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                                    _ = try? context.execute(batchDeleteRequest)
                                }
                                
                                _ = try? context.save()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .dismissKeyboardOnTap(focusedField: $isThresholdFieldFocused)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        isThresholdFieldFocused = false
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .sheet(isPresented: $viewModel.showingLanguageSheet) {
                LanguageSelectionSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingThemeSheet) {
                ThemeSelectionSheet(viewModel: viewModel)
            }
            .fileExporter(
                isPresented: $showingExportSheet,
                document: ExportDocument(data: exportData ?? Data()),
                contentType: .json,
                defaultFilename: "mizanflow_settings_\(viewModel.formatDate(Date()))"
            ) { result in
                switch result {
                case .success(let url):
                    AppLogger.ui.notice("Settings exported to: \(url.absoluteString, privacy: .public)")
                case .failure(let error):
                    AppLogger.ui.error("Export failed: \(String(describing: error), privacy: .public)")
                }
            }
            .alert(isPresented: Binding(
                get: { viewModel.showingLanguageRestartAlert },
                set: { viewModel.showingLanguageRestartAlert = $0 }
            )) {
                Alert(
                    title: Text(NSLocalizedString("Language Changed", comment: "")),
                    message: Text(NSLocalizedString("The app needs to restart to apply the new language. Would you like to restart now?", comment: "")),
                    primaryButton: .destructive(Text(NSLocalizedString("Restart Now", comment: ""))) {
                        exit(0)
                    },
                    secondaryButton: .cancel(Text(NSLocalizedString("Later", comment: "")))
                )
            }
        }
    }
}

struct LanguageSelectionSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Settings.Language.allCases, id: \.self) { language in
                    Button(action: {
                        viewModel.updateLanguage(language)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Text(viewModel.getLanguageDisplayName(language))
                            Spacer()
                            if language == viewModel.settings.language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Language")
            .navigationBarItems(
                trailing: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct ThemeSelectionSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Settings.Theme.allCases, id: \.self) { theme in
                    Button(action: {
                        viewModel.updateTheme(theme)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Text(viewModel.getThemeDisplayName(theme))
                            Spacer()
                            if theme == viewModel.settings.theme {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Theme")
            .navigationBarItems(
                trailing: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        data = Data()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
} 
