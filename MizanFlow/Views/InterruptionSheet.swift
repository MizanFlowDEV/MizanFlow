import SwiftUI

struct InterruptionSheet: View {
    @ObservedObject var viewModel: WorkScheduleViewModel
    @Environment(\.presentationMode) private var presentationMode
    @State private var selectedType: WorkSchedule.InterruptionType = .vacation
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var preferredReturnDay: WorkSchedule.Weekday?
    @State private var notes: String = ""
    @State private var showingDatePicker = false
    @State private var showingReturnDayPicker = false
    @State private var suggestModeResult: SuggestModeResult?
    @State private var showingSuggestionAlert = false
    @State private var suggestionAlertMessage = ""
    @State private var pendingSuggestion: SuggestModeSuggestion?
    
    // NEW: State variables for loop prevention and better alternative handling
    @State private var shownSuggestionIds: Set<String> = []
    @State private var showingBetterAlternativeAlert = false
    @State private var betterAlternative: SuggestModeSuggestion?
    
    // NEW: State variables for feedback messages
    @State private var feedbackMessage: String?
    @State private var showingFeedback: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                interruptionDetailsSection
                returnPreferencesSection
                vacationImpactSection
                suggestModeSection
                notesSection
            }
            .navigationTitle(NSLocalizedString("Schedule Interruption", comment: ""))
            .navigationBarItems(
                leading: Button(NSLocalizedString("Cancel", comment: "")) {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(NSLocalizedString("Done", comment: "")) {
                    handleInterruptionWithSuggestMode()
                }
            )
            .sheet(isPresented: $showingReturnDayPicker) {
                NavigationView {
                    List {
                        ForEach(WorkSchedule.Weekday.allCases, id: \.self) { day in
                            Button(action: {
                                preferredReturnDay = day
                                showingReturnDayPicker = false
                            }) {
                                HStack {
                                    Text(day.localizedName)
                                    Spacer()
                                    if preferredReturnDay == day {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle(NSLocalizedString("Select Return Day", comment: ""))
                    .navigationBarItems(
                        trailing: Button(NSLocalizedString("Done", comment: "")) {
                            showingReturnDayPicker = false
                        }
                    )
                }
            }
            .alert("Operational Constraints", isPresented: $showingSuggestionAlert) {
                Button("Accept Exception") {
                    if let suggestion = pendingSuggestion {
                        applySuggestion(suggestion)
                    }
                }
                Button("Suggest Alternative") {
                    handleSuggestAlternative()
                }
                Button("Cancel", role: .cancel) {
                    exitSuggestionFlow(message: "Suggestion cancelled. You can continue editing.")
                }
            } message: {
                Text(suggestionAlertMessage)
            }
            .alert("Better Alternative Found", isPresented: $showingBetterAlternativeAlert) {
                if let better = betterAlternative {
                    Button("Use This Alternative") {
                        pendingSuggestion = better
                        showingBetterAlternativeAlert = false
                        // User can then apply it via "Review & Apply" button
                    }
                    Button("Keep Current", role: .cancel) {
                        showingBetterAlternativeAlert = false
                    }
                }
            } message: {
                if let better = betterAlternative, let current = pendingSuggestion {
                    Text("""
                    Found a better alternative:
                    
                    Current: \(current.workDays) work / \(current.offDays) off (Score: \(Int(current.score)))
                    Better: \(better.workDays) work / \(better.offDays) off (Score: \(Int(better.score)))
                    
                    Warnings: \(better.validationWarnings.count + better.futureSimulationWarnings.count) vs \(current.validationWarnings.count + current.futureSimulationWarnings.count)
                    """)
                }
            }
            .overlay(
                Group {
                    if showingFeedback, let message = feedbackMessage {
                        VStack {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 5)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                            Spacer()
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut, value: showingFeedback)
                    }
                },
                alignment: .top
            )
        }
    }
    
    private var interruptionDetailsSection: some View {
        Section(header: Text("Interruption Details")) {
            Picker("Type", selection: $selectedType) {
                Text("Vacation").tag(WorkSchedule.InterruptionType.vacation)
                Text("Short Leave").tag(WorkSchedule.InterruptionType.shortLeave)
                Text("Training").tag(WorkSchedule.InterruptionType.training)
                Text("Company Off").tag(WorkSchedule.InterruptionType.companyOff)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
            DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
        }
    }
    
    private var returnPreferencesSection: some View {
        Section(header: Text(NSLocalizedString("Return Preferences", comment: ""))) {
            Button(action: { showingReturnDayPicker = true }) {
                HStack {
                    Text(NSLocalizedString("Specify Preferred Return Day", comment: ""))
                    Spacer()
                    if let returnDay = preferredReturnDay {
                        Text(returnDay.localizedName)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var vacationImpactSection: some View {
        Group {
            if selectedType == .vacation || selectedType == .shortLeave {
                Section(header: Text("Vacation Days Impact")) {
                    let (workDays, earnedDays) = calculateDisplayInfo()
                    let vacationDaysUsed = calculateVacationDaysUsed(earnedDays)
                    
                    HStack {
                        Text("Worked Days Before:")
                        Spacer()
                        Text("\(workDays) (current hitch)")
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Earned Off Days:")
                        Spacer()
                        Text("\(earnedDays) (from current hitch)")
                            .foregroundColor(.green)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Total Interruption Days:")
                        Spacer()
                        let totalDays = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
                        Text("\(totalDays + 1)")
                            .foregroundColor(.orange)
                    }
                    
                    HStack {
                        Text("Vacation Days Used:")
                        Spacer()
                        Text("\(vacationDaysUsed)")
                            .foregroundColor(.red)
                    }
                    
                    HStack {
                        Text("Current Balance:")
                        Spacer()
                        Text("\(viewModel.getVacationBalance())")
                            .foregroundColor(.blue)
                    }
                    
                    if viewModel.isManuallyAdjusted() {
                        Text("Note: Schedule has manual overrides. Automatic rescheduling is disabled.")
                            .font(.footnote)
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }
                    
                    // Show validation warnings (reuse earnedDays from above)
                    let validationWarnings = ScheduleEngine.shared.validateInterruptionPeriod(
                        startDate: startDate,
                        endDate: endDate,
                        earnedDays: earnedDays
                    )
                    
                    if !validationWarnings.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("⚠️ Validation Warnings:")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            
                            ForEach(validationWarnings, id: \.self) { warning in
                                Text("• \(warning)")
                                    .font(.footnote)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }
    
    private var suggestModeSection: some View {
        Group {
            if preferredReturnDay != nil {
                Section(header: Text("Suggest Mode Analysis")) {
                    Button(action: {
                        analyzeSuggestMode()
                    }) {
                        HStack {
                            Text("Analyze Schedule Adjustment")
                            Spacer()
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.blue)
                        }
                    }
                    
                        if let result = suggestModeResult {
                        if let suggestion = result.suggestion {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Suggested Adjustment:")
                                        .font(.headline)
                                    
                                    if !suggestion.isRecommended {
                                        Text("⚠️ Not Recommended")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.orange)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.orange.opacity(0.2))
                                            .cornerRadius(6)
                                    }
                                    
                                    Spacer()
                                }
                                
                                Text(suggestion.description)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Text("Work Days: \(suggestion.workDays)")
                                        .foregroundColor(.green)
                                    Spacer()
                                    Text("Off Days: \(suggestion.offDays)")
                                        .foregroundColor(.blue)
                                }
                                
                                // Show immediate validation warnings
                                if !suggestion.validationWarnings.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("⚠️ Validation Warnings:")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.orange)
                                        
                                        ForEach(suggestion.validationWarnings, id: \.self) { warning in
                                            Text("• \(warning)")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 4)
                                    .background(Color.orange.opacity(0.15))
                                    .cornerRadius(8)
                                }
                                
                                // Show future simulation warnings (CRITICAL)
                                if !suggestion.futureSimulationWarnings.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("⚠️ Future 14W/7O Alignment Concerns:")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.red)
                                        
                                        ForEach(suggestion.futureSimulationWarnings, id: \.self) { warning in
                                            Text("• \(warning)")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 4)
                                    .background(Color.red.opacity(0.15))
                                    .cornerRadius(8)
                                }
                                
                                if let impact = suggestion.impactOnSalary {
                                    Text("Salary Impact: \(impact)")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                
                                // Show alternatives with their warnings and scores
                                if !result.alternatives.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("💡 Alternative Suggestions:")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                        
                                        ForEach(result.alternatives.indices, id: \.self) { index in
                                            let alt = result.alternatives[index]
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    Text(alt.description)
                                                        .font(.caption)
                                                        .foregroundColor(.primary)
                                                    
                                                    if !alt.isRecommended {
                                                        Text("⚠️")
                                                            .font(.caption)
                                                            .foregroundColor(.orange)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    Text("Score: \(Int(alt.score))")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                HStack {
                                                    Text("\(alt.workDays) work / \(alt.offDays) off")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                    Spacer()
                                                    if let impact = alt.impactOnSalary {
                                                        Text(impact)
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                
                                                // Show warnings for alternatives
                                                if !alt.validationWarnings.isEmpty || !alt.futureSimulationWarnings.isEmpty {
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        if !alt.validationWarnings.isEmpty {
                                                            ForEach(alt.validationWarnings.prefix(1), id: \.self) { warning in
                                                                Text("⚠️ \(warning)")
                                                                    .font(.caption2)
                                                                    .foregroundColor(.orange)
                                                            }
                                                        }
                                                        if !alt.futureSimulationWarnings.isEmpty {
                                                            ForEach(alt.futureSimulationWarnings.prefix(1), id: \.self) { warning in
                                                                Text("⚠️ \(warning)")
                                                                    .font(.caption2)
                                                                    .foregroundColor(.red)
                                                            }
                                                        }
                                                    }
                                                }
                                                
                                                Button(action: {
                                                    if alt.isRecommended {
                                                        applySuggestion(alt)
                                                    } else {
                                                        pendingSuggestion = alt
                                                        showOperationalAlerts(result.alerts)
                                                    }
                                                }) {
                                                    Text(alt.isRecommended ? "Use This Alternative" : "Review & Apply (Requires Approval)")
                                                        .font(.caption)
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 6)
                                                        .background(alt.isRecommended ? Color.green : Color.orange)
                                                        .cornerRadius(6)
                                                }
                                            }
                                            .padding(8)
                                            .background(alt.isRecommended ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                                            .cornerRadius(6)
                                        }
                                    }
                                    .padding(.top, 8)
                                }
                                
                                // FIXED: Always require approval if warnings exist
                                if result.requiresUserApproval || !suggestion.validationWarnings.isEmpty || !suggestion.futureSimulationWarnings.isEmpty {
                                    Button(action: {
                                        pendingSuggestion = suggestion
                                        showOperationalAlerts(result.alerts)
                                    }) {
                                        Text("Review & Apply (Requires Approval)")
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color.orange)
                                            .cornerRadius(8)
                                    }
                                } else {
                                    Button(action: {
                                        applySuggestion(suggestion)
                                    }) {
                                        Text("Apply Suggestion")
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color.green)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        if !result.alerts.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("⚠️ Operational Constraints:")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                                
                                ForEach(result.alerts.indices, id: \.self) { index in
                                    Text("• \(result.alerts[index].message)")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .padding(.vertical, 2)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
    
    private var notesSection: some View {
        Section(header: Text("Notes")) {
            TextEditor(text: $notes)
                .frame(height: 100)
        }
    }
    
    private func calculateDisplayInfo() -> (workDays: Int, earnedDays: Int) {
        return viewModel.calculateWorkedAndEarnedDays(interruptionStart: startDate)
    }
    
    private func calculateVacationDaysUsed(_ earnedDays: Int) -> Int {
        return viewModel.calculateVacationDaysUsed(startDate: startDate, endDate: endDate, earnedDays: earnedDays)
    }
    
    // MARK: - Suggest Mode Functions
    
    private func analyzeSuggestMode() {
        guard let targetReturnDay = preferredReturnDay else { return }
        
        suggestModeResult = viewModel.getSuggestModeResult(
            interruptionStart: startDate,
            interruptionEnd: endDate,
            interruptionType: selectedType,
            targetReturnDay: targetReturnDay
        )
        
        // FIXED: Force validation check and log for debugging
        if let result = suggestModeResult {
            if !result.alerts.isEmpty {
                print("⚠️ Operational alerts detected: \(result.alerts.count) alerts")
            }
            if let suggestion = result.suggestion {
                if !suggestion.validationWarnings.isEmpty {
                    print("⚠️ Validation warnings detected for suggestion: \(suggestion.validationWarnings.joined(separator: ", "))")
                }
                if !suggestion.futureSimulationWarnings.isEmpty {
                    print("⚠️ Future simulation warnings detected: \(suggestion.futureSimulationWarnings.joined(separator: ", "))")
                }
            }
        }
    }
    
    private func handleInterruptionWithSuggestMode() {
        // CRITICAL: Prevent dismissal if ANY alert is showing
        // Alerts must only dismiss via explicit user action
        if showingSuggestionAlert || showingBetterAlternativeAlert {
            return
        }
        
        // FIXED: Warning gate - check all warnings before auto-applying
        if let result = suggestModeResult,
           let suggestion = result.suggestion,
           !result.requiresUserApproval,
           suggestion.validationWarnings.isEmpty,
           suggestion.futureSimulationWarnings.isEmpty {
            // Only auto-apply if no warnings exist
            applySuggestion(suggestion)
        } else {
            // Fallback to standard interruption handling
            viewModel.handleInterruptionWithEnhancedLogic(
                startDate: startDate,
                endDate: endDate,
                type: selectedType,
                preferredReturnDay: preferredReturnDay
            )
        }
        presentationMode.wrappedValue.dismiss()
    }
    
    private func applySuggestion(_ suggestion: SuggestModeSuggestion) {
        // Apply the suggestion to the schedule
        viewModel.applySuggestModeSuggestion(suggestion, to: &viewModel.schedule)
        
        // Then handle the interruption normally
        viewModel.handleInterruptionWithEnhancedLogic(
            startDate: startDate,
            endDate: endDate,
            type: selectedType,
            preferredReturnDay: preferredReturnDay
        )
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private func showOperationalAlerts(_ alerts: [OperationalAlert]) {
        var alertMessage = "Operational Constraints Detected:\n\n"
        
        for alert in alerts {
            alertMessage += "⚠️ \(alert.message)\n\n"
        }
        
        // REMOVED: Redundant "Options:" section - buttons already show the actions
        // The alert message should only explain the constraints, not list button options
        
        suggestionAlertMessage = alertMessage
        showingSuggestionAlert = true
        
        // Mark current suggestion as shown to prevent loops
        if let suggestion = pendingSuggestion {
            markSuggestionAsShown(suggestion)
        }
    }
    
    // MARK: - Loop Prevention Functions
    
    private func getSuggestionId(_ suggestion: SuggestModeSuggestion) -> String {
        return "\(suggestion.workDays)W-\(suggestion.offDays)O-\(suggestion.targetReturnDay.rawValue)"
    }
    
    private func isSuggestionAlreadyShown(_ suggestion: SuggestModeSuggestion) -> Bool {
        return shownSuggestionIds.contains(getSuggestionId(suggestion))
    }
    
    private func markSuggestionAsShown(_ suggestion: SuggestModeSuggestion) {
        shownSuggestionIds.insert(getSuggestionId(suggestion))
    }
    
    private func clearShownSuggestions() {
        shownSuggestionIds.removeAll()
    }
    
    // MARK: - Better Alternative Functions
    
    private func findBetterAlternative(
        current: SuggestModeSuggestion,
        alternatives: [SuggestModeSuggestion]
    ) -> SuggestModeSuggestion? {
        // Filter out already-shown suggestions
        let availableAlternatives = alternatives.filter { !isSuggestionAlreadyShown($0) }
        
        for alt in availableAlternatives {
            // Primary: Higher score
            if alt.score > current.score {
                return alt
            }
            // Secondary: Same score (within 5 points) but fewer warnings
            if abs(alt.score - current.score) <= 5.0 {
                let currentWarningCount = current.validationWarnings.count + current.futureSimulationWarnings.count
                let altWarningCount = alt.validationWarnings.count + alt.futureSimulationWarnings.count
                // Prioritize futureSimulationWarnings
                let currentFutureWarnings = current.futureSimulationWarnings.count
                let altFutureWarnings = alt.futureSimulationWarnings.count
                
                if altFutureWarnings < currentFutureWarnings {
                    return alt
                } else if altFutureWarnings == currentFutureWarnings && altWarningCount < currentWarningCount {
                    return alt
                }
            }
        }
        return nil
    }
    
    private func handleSuggestAlternative() {
        showingSuggestionAlert = false // Dismiss current alert
        
        if let result = suggestModeResult,
           let current = pendingSuggestion,
           let better = findBetterAlternative(current: current, alternatives: result.alternatives) {
            // Mark as shown to prevent showing again
            markSuggestionAsShown(better)
            // Show new alert with better alternative details
            betterAlternative = better
            showingBetterAlternativeAlert = true
        } else {
            // No better alternative available - exit suggestion flow
            exitSuggestionFlow(message: "No better suggestions available.")
        }
    }
    
    // MARK: - Exit Flow Function
    
    private func exitSuggestionFlow(message: String? = nil) {
        // Clear pending suggestion
        pendingSuggestion = nil
        
        // Dismiss all alerts
        showingSuggestionAlert = false
        showingBetterAlternativeAlert = false
        
        // Optional: Clear shown suggestions to allow fresh start
        // clearShownSuggestions()
        
        // Show feedback message if provided
        if let message = message {
            showFeedbackMessage(message)
        }
        
        // User remains on interruption sheet - can continue editing
    }
    
    // MARK: - Feedback Message Functions
    
    private func showFeedbackMessage(_ message: String) {
        feedbackMessage = message
        showingFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showingFeedback = false
            feedbackMessage = nil
        }
    }
}

struct InterruptionSheet_Previews: PreviewProvider {
    static var previews: some View {
        InterruptionSheet(viewModel: WorkScheduleViewModel())
    }
} 
