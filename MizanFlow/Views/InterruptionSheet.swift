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
    @State private var suggestionAlertMessage = ""
    @State private var pendingSuggestion: SuggestModeSuggestion?
    @State private var selectedAlternative: SuggestModeSuggestion? // Track user's selected alternative
    @State private var dialogSuggestion: SuggestModeSuggestion? // PART A: Freeze the selected suggestion that the dialog will apply
    
    // NEW: State variables for loop prevention and better alternative handling
    @State private var shownSuggestionIds: Set<String> = []
    @State private var betterAlternative: SuggestModeSuggestion?
    
    // FIXED: Use explicit dialog booleans instead of an enum + Binding(set:)
    // The enum approach was causing the confirmationDialog to auto-dismiss / misbehave during re-renders.
    @State private var showingOperationalConstraintsDialog: Bool = false
    @State private var showingBetterAlternativeAlert: Bool = false
    
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
            .confirmationDialog("Operational Constraints", isPresented: $showingOperationalConstraintsDialog, titleVisibility: .visible) {
                Button("Accept Exception") {
                    // PART A: Use dialogSuggestion (not pendingSuggestion) as the authoritative source
                    guard let suggestion = dialogSuggestion else {
                        print("⚠️ No dialogSuggestion when Accept Exception clicked")
                        showingOperationalConstraintsDialog = false
                        return
                    }
                    print("✅ Accept Exception - Applying binding alternative: \(suggestion.workDays)W/\(suggestion.offDays)O, Score: \(Int(suggestion.score))")
                    showingOperationalConstraintsDialog = false
                    // Clear both states
                    dialogSuggestion = nil
                    pendingSuggestion = nil
                    // Apply the suggestion
                    applySuggestion(suggestion)
                }
                Button("Suggest Alternative") {
                    showingOperationalConstraintsDialog = false
                    handleSuggestAlternative()
                }
                Button("Cancel", role: .cancel) {
                    // PART A: Clear dialogSuggestion and pendingSuggestion, keep user on sheet
                    dialogSuggestion = nil
                    pendingSuggestion = nil
                    showingOperationalConstraintsDialog = false
                    exitSuggestionFlow(message: "Suggestion cancelled. You can continue editing.")
                }
            } message: {
                Text(suggestionAlertMessage)
            }
            .alert("Better Alternative Found", isPresented: $showingBetterAlternativeAlert) {
                Button("Use This Alternative") {
                    // PART A: Set BOTH dialogSuggestion and pendingSuggestion when user chooses
                    if let better = betterAlternative {
                        dialogSuggestion = better
                        pendingSuggestion = better
                        showingBetterAlternativeAlert = false
                        showOperationalAlerts(for: better)
                    }
                }
                Button("Keep Current", role: .cancel) {
                    showingBetterAlternativeAlert = false
                }
            } message: {
                if let better = betterAlternative, let current = pendingSuggestion {
                    Text("""
                    Found a better alternative:
                    
                    Current: \(current.workDays) work / \(current.offDays) off (Score: \(Int(current.score)))
                    Better: \(better.workDays) work / \(better.offDays) off (Score: \(Int(better.score)))
                    
                    Warnings: \(better.validationWarnings.count + better.futureSimulationWarnings.count) vs \(current.validationWarnings.count + current.futureSimulationWarnings.count)
                    """)
                } else {
                    Text("Found a better alternative.")
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
                        suggestionContentView(result: result)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views for Suggest Mode
    
    @ViewBuilder
    private func suggestionContentView(result: SuggestModeResult) -> some View {
        if let suggestion = result.suggestion {
            primarySuggestionView(suggestion: suggestion, result: result)
        }
        
        if !result.alerts.isEmpty {
            operationalConstraintsView(alerts: result.alerts)
        }
    }
    
    @ViewBuilder
    private func primarySuggestionView(suggestion: SuggestModeSuggestion, result: SuggestModeResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            suggestionHeaderView(suggestion: suggestion)
            suggestionDetailsView(suggestion: suggestion)
            suggestionWarningsView(suggestion: suggestion)
            
            if let impact = suggestion.impactOnSalary {
                Text("Salary Impact: \(impact)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            if !result.alternatives.isEmpty {
                alternativesListView(alternatives: result.alternatives, result: result)
            }
            
            suggestionActionButtons(suggestion: suggestion, result: result)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func suggestionHeaderView(suggestion: SuggestModeSuggestion) -> some View {
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
    }
    
    @ViewBuilder
    private func suggestionDetailsView(suggestion: SuggestModeSuggestion) -> some View {
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
    }
    
    @ViewBuilder
    private func suggestionWarningsView(suggestion: SuggestModeSuggestion) -> some View {
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
    }
    
    @ViewBuilder
    private func alternativesListView(alternatives: [SuggestModeSuggestion], result: SuggestModeResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("💡 Alternative Suggestions:")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            
            ForEach(Array(alternatives.enumerated()), id: \.offset) { index, alt in
                alternativeItemView(alt: alt, result: result)
                    .id("\(alt.workDays)-\(alt.offDays)-\(alt.targetReturnDay.rawValue)")
            }
        }
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private func alternativeItemView(alt: SuggestModeSuggestion, result: SuggestModeResult) -> some View {
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
            
            if !alt.validationWarnings.isEmpty || !alt.futureSimulationWarnings.isEmpty {
                alternativeWarningsView(alt: alt)
            }
            
            Button(action: {
                // Track the selected alternative
                selectedAlternative = alt
                if alt.isRecommended {
                    print("✅ Direct apply (recommended): \(alt.workDays)W/\(alt.offDays)O, Score: \(Int(alt.score))")
                    applySuggestion(alt)
                } else {
                    // PART A: Set BOTH dialogSuggestion and pendingSuggestion when user chooses alternative requiring approval
                    dialogSuggestion = alt
                    pendingSuggestion = alt
                    print("🎯 Selected Alternative: \(alt.workDays)W/\(alt.offDays)O, Score: \(Int(alt.score)), Warnings: \(alt.validationWarnings.count + alt.futureSimulationWarnings.count)")
                    showOperationalAlerts(for: alt)
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
    
    @ViewBuilder
    private func alternativeWarningsView(alt: SuggestModeSuggestion) -> some View {
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
    
    @ViewBuilder
    private func suggestionActionButtons(suggestion: SuggestModeSuggestion, result: SuggestModeResult) -> some View {
        if result.requiresUserApproval || !suggestion.validationWarnings.isEmpty || !suggestion.futureSimulationWarnings.isEmpty {
            Button(action: {
                // PART A: Set BOTH dialogSuggestion and pendingSuggestion when user chooses primary suggestion
                dialogSuggestion = suggestion
                pendingSuggestion = suggestion
                showOperationalAlerts(for: suggestion)
            }) {
                Text("Review & Apply (Requires Approval)")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(8)
            }
        } else {
            Button(action: {
                // Track the selected suggestion
                selectedAlternative = suggestion
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
    
    @ViewBuilder
    private func operationalConstraintsView(alerts: [OperationalAlert]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("⚠️ Operational Constraints:")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
            
            ForEach(alerts.indices, id: \.self) { index in
                Text("• \(alerts[index].message)")
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
        // PART B: Prevent dismissal if ANY alert is showing
        // Alerts must only dismiss via explicit user action
        if showingOperationalConstraintsDialog || showingBetterAlternativeAlert {
            return
        }
        
        // PART B: PRIORITY 1: If user has selected an alternative, use it
        if let selected = selectedAlternative {
            print("✅ Using user-selected alternative: \(selected.workDays)W/\(selected.offDays)O")
            applySuggestion(selected)
            return
        }
        
        // PART B: PRIORITY 2: If user is reviewing an option (dialogSuggestion != nil), show approval dialog
        // DO NOT infer cancellation from pendingSuggestion - it's only for loop prevention
        if let dialog = dialogSuggestion {
            // User has selected something but hasn't approved yet - show dialog
            showOperationalAlerts(for: dialog)
            return
        }
        
        // PART B: PRIORITY 3: If suggestModeResult exists and requires approval, show alert for primary suggestion
        // ONLY if user hasn't selected something yet
        if let result = suggestModeResult,
           let suggestion = result.suggestion,
           dialogSuggestion == nil {
            // Check if this suggestion needs approval
            if result.requiresUserApproval ||
               !suggestion.validationWarnings.isEmpty ||
               !suggestion.futureSimulationWarnings.isEmpty {
                dialogSuggestion = suggestion
                pendingSuggestion = suggestion
                showOperationalAlerts(result.alerts)
                return
            }
        }
        
        // PART B: PRIORITY 4: Auto-apply only if no warnings and no approval needed
        if let result = suggestModeResult,
           let suggestion = result.suggestion,
           !result.requiresUserApproval,
           suggestion.validationWarnings.isEmpty,
           suggestion.futureSimulationWarnings.isEmpty {
            applySuggestion(suggestion)
        } else {
            // PART B: Fallback to standard interruption handling only if no suggestion selected
            viewModel.handleInterruptionWithEnhancedLogic(
                startDate: startDate,
                endDate: endDate,
                type: selectedType,
                preferredReturnDay: preferredReturnDay
            )
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func applySuggestion(_ suggestion: SuggestModeSuggestion) {
        // PART E: Add definitive debug log to prove binding works
        let source = (dialogSuggestion?.workDays == suggestion.workDays && dialogSuggestion?.offDays == suggestion.offDays) ? "Dialog" : 
                     (selectedAlternative?.workDays == suggestion.workDays && selectedAlternative?.offDays == suggestion.offDays) ? "Alternative" : "Primary"
        print("""
        🎯 InterruptionSheet.applySuggestion called:
           Source: \(source)
           Pattern: \(suggestion.workDays)W/\(suggestion.offDays)O
           Score: \(Int(suggestion.score))
           Is Recommended: \(suggestion.isRecommended)
           Validation Warnings: \(suggestion.validationWarnings.count)
           Future Warnings: \(suggestion.futureSimulationWarnings.count)
           Interruption: \(startDate) to \(endDate)
           Preferred Return Day: \(preferredReturnDay?.description ?? "None")
           Target Return Day: \(suggestion.targetReturnDay.description)
        """)
        
        // PART C: Clear all state - applySuggestion is authoritative, nothing should override it
        pendingSuggestion = nil
        dialogSuggestion = nil
        selectedAlternative = nil
        
        // PART C: Use binding method to ensure the alternative is actually applied as a concrete schedule block
        // This is the ONLY place that applies suggestions - no other handlers should be called after this
        viewModel.applyInterruptWithExecutableAlternative(
            interruptionType: selectedType,
            interruptionStart: startDate,
            interruptionEnd: endDate,
            preferredReturnDay: preferredReturnDay,
            selectedAlternative: suggestion
        )
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private func showOperationalAlerts(_ alerts: [OperationalAlert]) {
        // Legacy helper retained (calls the new helper)
        if let suggestion = pendingSuggestion {
            showOperationalAlerts(for: suggestion)
        } else {
            suggestionAlertMessage = alerts.isEmpty ? "Operational Constraints Detected." : alerts.map { "⚠️ \($0.message)" }.joined(separator: "\n")
            showingOperationalConstraintsDialog = true
        }
    }

    // FIXED: Build dialog content from the *selected suggestion*, not the primary result alerts list.
    private func showOperationalAlerts(for suggestion: SuggestModeSuggestion) {
        var alertMessage = "Operational Constraints Detected:\n\n"

        if !suggestion.validationWarnings.isEmpty {
            alertMessage += "Validation:\n"
            for w in suggestion.validationWarnings {
                alertMessage += "⚠️ \(w)\n"
            }
            alertMessage += "\n"
        }

        if !suggestion.futureSimulationWarnings.isEmpty {
            alertMessage += "Future Alignment:\n"
            for w in suggestion.futureSimulationWarnings {
                alertMessage += "⚠️ \(w)\n"
            }
            alertMessage += "\n"
        }

        if suggestion.validationWarnings.isEmpty && suggestion.futureSimulationWarnings.isEmpty {
            alertMessage += "This option requires approval based on operational rules."
        }

        suggestionAlertMessage = alertMessage
        showingOperationalConstraintsDialog = true

        // Mark suggestion as shown to prevent loops
        markSuggestionAsShown(suggestion)
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
        // Mark current suggestion as shown to prevent loops
        if let current = pendingSuggestion {
            markSuggestionAsShown(current)
        }
        
        // Dismiss current dialog
        showingOperationalConstraintsDialog = false
        
        if let result = suggestModeResult,
           let current = pendingSuggestion,
           let better = findBetterAlternative(current: current, alternatives: result.alternatives) {
            // Mark better alternative as shown
            markSuggestionAsShown(better)
            betterAlternative = better
            showingBetterAlternativeAlert = true
        } else {
            // No better alternative available - exit suggestion flow
            exitSuggestionFlow(message: "No better suggestions available.")
        }
    }
    
    // MARK: - Exit Flow Function
    
    private func exitSuggestionFlow(message: String? = nil) {
        // PART A: Clear both dialogSuggestion and pendingSuggestion
        dialogSuggestion = nil
        pendingSuggestion = nil
        
        // Dismiss all alerts
        showingOperationalConstraintsDialog = false
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
