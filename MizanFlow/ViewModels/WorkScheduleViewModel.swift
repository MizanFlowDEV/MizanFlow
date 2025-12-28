import Foundation
import SwiftUI
import os

@MainActor
class WorkScheduleViewModel: ObservableObject {
    @Published var schedule: WorkSchedule
    @Published var selectedDate: Date = Date()
    @Published var showingDayDetail = false
    @Published var showingInterruptionSheet = false
    @Published var showingOverrideSheet = false
    @Published var hitchStartDate: Date?
    @Published var showingRescheduleAlert = false
    @Published var rescheduleMessage: String = ""
    @Published var vacationBalance: Int = 30
    
    private let scheduleEngine = ScheduleEngine.shared
    private let dataService = DataPersistenceService.shared
    private let alertService = SmartAlertService.shared
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MizanFlow", category: "ViewModel")
    
    private var lastSaveDate: Date?
    
    private func saveDebounced(minInterval: TimeInterval = 0.5) {
        let now = Date()
        if let last = lastSaveDate, now.timeIntervalSince(last) < minInterval {
            return
        }
        lastSaveDate = now
        saveSchedule()
    }
    
    init(startDate: Date = Date()) {
        self.schedule = scheduleEngine.generateSchedule(from: startDate)
        loadSavedSchedule()
        
        // Generate initial schedule if no days exist
        if self.schedule.days.isEmpty {
            saveSchedule()
        }
        
        // Load hitch start date from Core Data
        if let savedHitchStartDate = schedule.hitchStartDate {
            self.hitchStartDate = savedHitchStartDate
        }
        
        // Load vacation balance from Core Data
        self.vacationBalance = schedule.vacationBalance
    }
    
    private func loadSavedSchedule() {
        if let savedSchedule = dataService.loadSchedule(id: schedule.id) {
            self.schedule = savedSchedule
        }
    }
    
    func saveSchedule() {
        // Single save path through DataPersistenceService
        // Use background save for better performance
        PerformanceMonitor.shared.measure("save_schedule") {
            dataService.saveScheduleInBackground(schedule)
        }
    }
    
    // MARK: - Unified Interruption Handling
    
    /// Unified method for handling interruptions with consistent logic
    /// - Parameters:
    ///   - startDate: Start date of interruption
    ///   - endDate: End date of interruption
    ///   - type: Type of interruption
    ///   - preferredReturnDay: Optional preferred return day
    ///   - reschedulingMode: Mode of rescheduling (default: .standard)
    func handleInterruption(
        startDate: Date,
        endDate: Date,
        type: WorkSchedule.InterruptionType,
        preferredReturnDay: WorkSchedule.Weekday? = nil,
        reschedulingMode: ReschedulingMode = .standard
    ) {
        // Check if this is a manual override
        if schedule.manuallyAdjusted {
            self.rescheduleMessage = "Manual override detected. The schedule will not be automatically recalculated."
            self.showingRescheduleAlert = true
            // For flexible mode, return early if manually adjusted
            if reschedulingMode == .flexible {
                return
            }
        }
        
        // Pre-calculate worked days and earned off days for display
        let (_, earnedDays) = scheduleEngine.calculateWorkedAndEarnedDaysBeforeInterruption(schedule, interruptionStart: startDate)
        
        // Validate interruption period setup
        let validationWarnings = scheduleEngine.validateInterruptionPeriod(
            startDate: startDate,
            endDate: endDate,
            earnedDays: earnedDays
        )
        
        if !validationWarnings.isEmpty {
            let warningMessage = "⚠️ Validation Warnings:\n" + validationWarnings.joined(separator: "\n")
            self.rescheduleMessage = warningMessage
            self.showingRescheduleAlert = true
        }
        
        // Special handling for training
        if type == .training {
            // Check if training overlaps with off days
            if scheduleEngine.checkTrainingOverlapsOffDays(schedule, startDate: startDate, endDate: endDate) {
                let message = reschedulingMode == .flexible
                    ? "Training overlaps with off days. Flexible rescheduling will optimize work patterns to accommodate training during work periods."
                    : reschedulingMode == .enhanced
                    ? "Training overlaps with off days. Enhanced rescheduling will optimize work patterns to accommodate training during work periods."
                    : "Training overlaps with off days. Training days will be rescheduled to fall on work days."
                self.rescheduleMessage = message
                self.showingRescheduleAlert = true
            }
        }
        
        // Handle vacation balance calculation (extracted to single method)
        updateVacationBalanceForInterruption(startDate: startDate, endDate: endDate, type: type, earnedDays: earnedDays)
        
        // Apply the interruption
        scheduleEngine.handleInterruption(&schedule, startDate: startDate, endDate: endDate, type: type, preferredReturnDay: preferredReturnDay)
        saveSchedule()
        
        HapticFeedback.saveSuccess()
        
        // Notify user about successful operation
        if !self.showingRescheduleAlert {
            let modeMessage = reschedulingMode == .flexible
                ? "using flexible rescheduling"
                : reschedulingMode == .enhanced
                ? "using enhanced rescheduling logic"
                : ""
            let message = modeMessage.isEmpty
                ? "Schedule successfully updated with \(type.rawValue) interruption."
                : "Schedule successfully updated with \(type.rawValue) interruption \(modeMessage)."
            self.rescheduleMessage = message
            self.showingRescheduleAlert = true
        }
    }
    
    /// Rescheduling mode enum
    enum ReschedulingMode {
        case standard
        case enhanced
        case flexible
    }
    
    /// Extracted vacation balance calculation logic
    private func updateVacationBalanceForInterruption(
        startDate: Date,
        endDate: Date,
        type: WorkSchedule.InterruptionType,
        earnedDays: Int
    ) {
        // Special handling for vacation
        if type == .vacation || type == .shortLeave {
            // Calculate total interruption days
            let totalDays = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
            let totalInterruptionDays = totalDays + 1 // Include both start and end date
            
            // Calculate how many vacation days will be used (after earned off days)
            let vacationDaysUsed = max(0, totalInterruptionDays - earnedDays)
            
            // Update vacation balance
            self.vacationBalance -= vacationDaysUsed
            self.schedule.vacationBalance = self.vacationBalance
            
            if vacationDaysUsed > 0 {
                self.rescheduleMessage = "Using \(vacationDaysUsed) vacation days. Remaining balance: \(self.vacationBalance) days."
                self.showingRescheduleAlert = true
            }
        }
    }
    
    func applyManualOverride(for date: Date, type: DayType, notes: String? = nil) {
        scheduleEngine.applyManualOverride(&schedule, for: date, type: type, notes: notes)
        saveSchedule()
        
        // Show alert if this is the first manual override
        if !self.showingRescheduleAlert {
            self.rescheduleMessage = "Manual override applied. Automatic rescheduling disabled for this hitch."
            self.showingRescheduleAlert = true
        }
    }
    
    func resetManualAdjustments() {
        scheduleEngine.resetManualAdjustments(&schedule)
        saveSchedule()
        
        self.rescheduleMessage = "All manual overrides cleared. Automatic rescheduling re-enabled."
        self.showingRescheduleAlert = true
    }
    
    func getDaysForMonth(_ date: Date) -> [WorkSchedule.ScheduleDay] {
        let calendar = Calendar.current
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return []
        }

        // Normalize dates to start of day for accurate comparison
        let normalizedMonthStart = calendar.startOfDay(for: monthStart)
        let normalizedMonthEnd = calendar.startOfDay(for: monthEnd)

        // Filter days for the selected month
        let daysInMonth = schedule.days.filter { day in
            let normalizedDayDate = calendar.startOfDay(for: day.date)
            return normalizedDayDate >= normalizedMonthStart && normalizedDayDate <= normalizedMonthEnd
        }

        // If no days exist for this month, generate enough months to cover the selected date
        if daysInMonth.isEmpty {
            let startDateToUse = hitchStartDate ?? selectedDate
            let monthsNeeded = calendar.dateComponents([.month], from: calendar.startOfDay(for: startDateToUse), to: calendar.startOfDay(for: date)).month ?? 0
            // Always at least 1 month, add a buffer
            let monthsToGenerate = max(monthsNeeded + 1, 3)
            
            // Generate schedule in background for better performance
            Task { @MainActor in
                let scheduleEngine = self.scheduleEngine
                let hitchStart = self.hitchStartDate
                self.schedule = await Task.detached(priority: .userInitiated) {
                    scheduleEngine.generateSchedule(from: startDateToUse, for: monthsToGenerate, hitchStartDate: hitchStart)
                }.value
                saveSchedule()
            }
            
            // Return empty for now, will update when generation completes
            return []
        }

        // Process days to mark which ones are within the hitch pattern
        var processedDays = daysInMonth
        if let hitchStart = hitchStartDate {
            for i in 0..<processedDays.count {
                // Calculate where in the 21-day cycle this date falls
                let daysSinceStart = calendar.dateComponents([.day], from: hitchStart, to: processedDays[i].date).day ?? 0
                let cyclePosition = (daysSinceStart % 21 + 21) % 21 // Ensure positive
                // First 14 days are workdays in the hitch
                processedDays[i].isInHitch = cyclePosition < 14
            }
        }

        return processedDays
    }
    
    func getDayType(for date: Date) -> DayType {
        if let day = schedule.days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            return day.type
        }
        return .workday
    }
    
    func isOverride(for date: Date) -> Bool {
        if let day = schedule.days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            return day.isOverride
        }
        return false
    }
    
    func getNotes(for date: Date) -> String? {
        if let day = schedule.days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            return day.notes
        }
        return nil
    }
    
    func getOvertimeHours(for date: Date) -> Double? {
        if let day = schedule.days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            return day.overtimeHours
        }
        return nil
    }
    
    func hasIcon(for date: Date) -> Bool {
        if let day = schedule.days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            return day.hasIcon
        }
        return false
    }
    
    func getIconName(for date: Date) -> String? {
        if let day = schedule.days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            return day.iconName
        }
        return nil
    }
    
    func getMonthString(_ date: Date) -> String {
        return FormattingUtilities.formatMonth(date)
    }
    
    func getFirstWeekdayOfMonth(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let firstDayOfMonth = calendar.date(from: components) else {
            return 1 // Default to Sunday if date calculation fails
        }
        return calendar.component(.weekday, from: firstDayOfMonth)
    }
    
    func getWeekdaySymbols() -> [String] {
        return Calendar.current.shortWeekdaySymbols
    }
    
    func getHitchDayPosition(for date: Date) -> Int {
        guard let hitchStart = hitchStartDate else { return 0 }
        
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: hitchStart, to: date).day ?? 0
        
        // Return position in the 21-day cycle (14 work, 7 off)
        return days % 21
    }
    
    // MARK: - Helper for Smart Reschedule
    func getEarnedOffDaysBeforeInterruption() -> Int {
        // Make sure we display the correct value
        if let earnedDays = schedule.earnedOffDaysBeforeInterruption {
            return earnedDays
        } else {
            // If not calculated yet, compute it on the fly
            if let start = schedule.interruptionStart {
                let (_, earned) = scheduleEngine.calculateWorkedAndEarnedDaysBeforeInterruption(schedule, interruptionStart: start)
                return earned
            }
            return 0
        }
    }
    
    func getWorkedDaysBeforeInterruption() -> Int {
        // Make sure we display the correct value
        if let workedDays = schedule.workedDaysBeforeInterruption {
            return workedDays
        } else {
            // If not calculated yet, compute it on the fly
            if let start = schedule.interruptionStart {
                let (worked, _) = scheduleEngine.calculateWorkedAndEarnedDaysBeforeInterruption(schedule, interruptionStart: start)
                return worked
            }
            return 0
        }
    }
    
    // Public method for InterruptionSheet to calculate worked and earned days
    func calculateWorkedAndEarnedDays(interruptionStart: Date) -> (workDays: Int, earnedDays: Int) {
        let (worked, earned) = scheduleEngine.calculateWorkedAndEarnedDaysBeforeInterruption(schedule, interruptionStart: interruptionStart)
        return (workDays: worked, earnedDays: earned)
    }
    
    // Calculate vacation days that would be used for the given interruption
    // This uses the same calculation logic as ScheduleEngine for consistency
    func calculateVacationDaysUsed(startDate: Date, endDate: Date, earnedDays: Int) -> Int {
        let calendar = Calendar.current
        let totalDays = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        let totalInterruptionDays = totalDays + 1  // Include both start and end date
        // Vacation days are counted after earned off days are used
        return max(0, totalInterruptionDays - earnedDays)
    }
    
    // Public method to calculate vacation days used from current interruption
    func calculateVacationDaysUsed() -> Int {
        guard let start = schedule.interruptionStart, 
              let end = schedule.interruptionEnd else {
            return 0
        }
        
        return scheduleEngine.calculateVacationDaysUsed(schedule, startDate: start, endDate: end)
    }
    
    func isManuallyAdjusted() -> Bool {
        return schedule.manuallyAdjusted
    }
    
    func getVacationBalance() -> Int {
        return self.vacationBalance
    }
    
    func setVacationBalance(_ balance: Int) {
        self.vacationBalance = balance
        self.schedule.vacationBalance = balance
        saveDebounced()
    }
    
    func removeCurrentInterruption() {
        // Store the current date to use after resetting
        let originalDate = self.selectedDate
        
        // If it's a vacation interruption, we need to restore the vacation balance
        if let type = schedule.interruptionType,
           (type == .vacation || type == .shortLeave),
           let interruptionStart = schedule.interruptionStart,
           let interruptionEnd = schedule.interruptionEnd {
            let vacationDaysUsed = scheduleEngine.calculateVacationDaysUsed(
                schedule, 
                startDate: interruptionStart, 
                endDate: interruptionEnd
            )
            
            // Restore the vacation days that were used
            self.vacationBalance += vacationDaysUsed
            self.schedule.vacationBalance = self.vacationBalance
        }
        
        // Remove the interruption from the schedule
        scheduleEngine.removeInterruption(&schedule)
        
        // Explicitly refresh the current month's days to ensure the view updates correctly
        let currentMonth = self.selectedDate
        let _ = self.getDaysForMonth(currentMonth) // Force a refresh of the current month
        
        // Force refresh by triggering objectWillChange
        objectWillChange.send()
        
        // Ensure we're looking at the same date after refresh
        self.selectedDate = originalDate
        
        // Save the updated schedule
        saveDebounced()
        
        // Notify user
        self.rescheduleMessage = "Interruption has been removed. Schedule restored to original pattern."
        self.showingRescheduleAlert = true
    }
    
    func setHitchStartDate(_ date: Date) {
        // #region agent log
        let logEntry = "{\"location\":\"WorkScheduleViewModel.swift:431\",\"message\":\"setHitchStartDate ENTRY\",\"data\":{\"newDate\":\"\(date.formatted(date: .abbreviated, time: .omitted))\",\"scheduleId\":\"\(schedule.id.uuidString)\",\"oldHitchStartDate\":\"\(schedule.hitchStartDate?.formatted(date: .abbreviated, time: .omitted) ?? "nil")\"},\"timestamp\":\(Int(Date().timeIntervalSince1970*1000)),\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"E\"}\n"
        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: "/Users/busaad/AppDev/MizanFlow/.cursor/debug.log") {
                if let fileHandle = FileHandle(forWritingAtPath: "/Users/busaad/AppDev/MizanFlow/.cursor/debug.log") {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                FileManager.default.createFile(atPath: "/Users/busaad/AppDev/MizanFlow/.cursor/debug.log", contents: data, attributes: nil)
            }
        }
        // #endregion
        
        self.hitchStartDate = date
        self.schedule.hitchStartDate = date
        
        // Perform heavy schedule generation in background
        Task { @MainActor in
            // Preserve the existing schedule ID so we update the same schedule entity
            let existingScheduleId = self.schedule.id
            
            // Create a new schedule from this hitch start date
            let scheduleEngine = self.scheduleEngine
            var newSchedule = await Task.detached(priority: .userInitiated) {
                scheduleEngine.generateSchedule(from: date, hitchStartDate: date)
            }.value
            
            // Preserve the existing schedule ID and other important properties
            newSchedule.id = existingScheduleId
            newSchedule.hitchStartDate = date  // CRITICAL: Set hitchStartDate on the new schedule
            newSchedule.isInterrupted = self.schedule.isInterrupted
            newSchedule.interruptionStart = self.schedule.interruptionStart
            newSchedule.interruptionEnd = self.schedule.interruptionEnd
            newSchedule.interruptionType = self.schedule.interruptionType
            newSchedule.vacationBalance = self.schedule.vacationBalance
            newSchedule.manuallyAdjusted = self.schedule.manuallyAdjusted
            
            // #region agent log
            let logAfterSet = "{\"location\":\"WorkScheduleViewModel.swift:470\",\"message\":\"After setting hitchStartDate on newSchedule\",\"data\":{\"hitchStartDate\":\"\(newSchedule.hitchStartDate?.formatted(date: .abbreviated, time: .omitted) ?? "nil")\",\"scheduleId\":\"\(newSchedule.id.uuidString)\"},\"timestamp\":\(Int(Date().timeIntervalSince1970*1000)),\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"E\"}\n"
            if let data = logAfterSet.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: "/Users/busaad/AppDev/MizanFlow/.cursor/debug.log") {
                    if let fileHandle = FileHandle(forWritingAtPath: "/Users/busaad/AppDev/MizanFlow/.cursor/debug.log") {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    FileManager.default.createFile(atPath: "/Users/busaad/AppDev/MizanFlow/.cursor/debug.log", contents: data, attributes: nil)
                }
            }
            // #endregion
            
            self.schedule = newSchedule
            
            // Apply holiday pay rules
            scheduleEngine.handleHolidayPayRules(&schedule)
            
            // #region agent log
            let logBeforeSave = "{\"location\":\"WorkScheduleViewModel.swift:446\",\"message\":\"About to save schedule after setHitchStartDate\",\"data\":{\"hitchStartDate\":\"\(self.schedule.hitchStartDate?.formatted(date: .abbreviated, time: .omitted) ?? "nil")\",\"scheduleId\":\"\(self.schedule.id.uuidString)\"},\"timestamp\":\(Int(Date().timeIntervalSince1970*1000)),\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"E\"}\n"
            if let data = logBeforeSave.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: "/Users/busaad/AppDev/MizanFlow/.cursor/debug.log") {
                    if let fileHandle = FileHandle(forWritingAtPath: "/Users/busaad/AppDev/MizanFlow/.cursor/debug.log") {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    FileManager.default.createFile(atPath: "/Users/busaad/AppDev/MizanFlow/.cursor/debug.log", contents: data, attributes: nil)
                }
            }
            // #endregion
            
            saveDebounced()
            
            self.rescheduleMessage = "Hitch start date set to \(formatDate(date)). New 14/7 schedule generated."
            self.showingRescheduleAlert = true
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        return FormattingUtilities.formatDate(date)
    }
    
    func getDayDescription(for type: DayType) -> String {
        return type.description
    }
    
    func isHoliday(type: DayType) -> Bool {
        return type == .eidHoliday || type == .nationalDay || type == .foundingDay
    }
    
    func isCurrentDayInActiveHitch(date: Date) -> Bool {
        // Calculate where in the 21-day cycle this date falls
        guard let hitchStart = hitchStartDate else { return false }
        
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: hitchStart, to: date).day ?? 0
        let cyclePosition = daysSinceStart % 21
        
        // First 14 days are workdays in the hitch
        return cyclePosition < 14
    }
    
    /// Resets the schedule to initial state
    /// Note: This only resets the ViewModel state. For full data wipe, use PersistenceController.wipeAllData()
    func reset() {
        let startDate = Date()
        self.schedule = scheduleEngine.generateSchedule(from: startDate)
        self.vacationBalance = 30
        self.hitchStartDate = nil
        self.schedule.hitchStartDate = nil
        self.schedule.vacationBalance = 30
        saveDebounced()
    }
    
    // MARK: - Suggest Mode Integration
    
    func getSuggestModeResult(
        interruptionStart: Date,
        interruptionEnd: Date,
        interruptionType: WorkSchedule.InterruptionType,
        targetReturnDay: WorkSchedule.Weekday
    ) -> SuggestModeResult {
        return scheduleEngine.suggestModeWithOperationalConstraints(
            schedule: schedule,
            interruptionStart: interruptionStart,
            interruptionEnd: interruptionEnd,
            interruptionType: interruptionType,
            targetReturnDay: targetReturnDay
        )
    }
    
    // FIXED: New method signature that properly applies suggestion
    func applySuggestModeSuggestion(
        _ suggestion: SuggestModeSuggestion,
        interruptionStart: Date,
        interruptionEnd: Date,
        type: WorkSchedule.InterruptionType
    ) {
        // #region agent log
        if let logData = try? JSONSerialization.data(withJSONObject: ["location":"WorkScheduleViewModel.swift:501","message":"applySuggestModeSuggestion ENTRY","data":["suggestionWorkDays":suggestion.workDays,"suggestionOffDays":suggestion.offDays,"suggestionScore":suggestion.score],"timestamp":Int(Date().timeIntervalSince1970*1000),"sessionId":"debug-session","runId":"run1","hypothesisId":"H3"]), let logString = String(data: logData, encoding: .utf8) {
            try? (logString + "\n").write(toFile: "/Users/busaad/AppDev/MizanFlow/.cursor/debug.log", atomically: true, encoding: .utf8)
        }
        // #endregion
        // Log selected suggestion for verification
        logger.debug("""
        🎯 Applying Suggest Mode Suggestion:
           Pattern: \(suggestion.workDays)W/\(suggestion.offDays)O
           Interruption: \(interruptionStart, privacy: .public) to \(interruptionEnd, privacy: .public)
           Type: \(type.rawValue, privacy: .public)
        """)
        
        // #region agent log
        let logEngine = "{\"location\":\"WorkScheduleViewModel.swift:515\",\"message\":\"About to call scheduleEngine.applySuggestModeSuggestion\",\"data\":{\"suggestionW\":\(suggestion.workDays),\"suggestionO\":\(suggestion.offDays)},\"timestamp\":\(Int(Date().timeIntervalSince1970*1000)),\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"H3\"}\n"
        if let data = logEngine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: "/Users/busaad/AppDev/MizanFlow/.cursor/debug.log") {
                if let fileHandle = FileHandle(forWritingAtPath: "/Users/busaad/AppDev/MizanFlow/.cursor/debug.log") {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                FileManager.default.createFile(atPath: "/Users/busaad/AppDev/MizanFlow/.cursor/debug.log", contents: data, attributes: nil)
            }
        }
        print("🔍 DEBUG: ViewModel calling scheduleEngine with: \(suggestion.workDays)W/\(suggestion.offDays)O")
        // #endregion
        scheduleEngine.applySuggestModeSuggestion(
            &schedule,
            suggestion: suggestion,
            interruptionStart: interruptionStart,
            interruptionEnd: interruptionEnd,
            interruptionType: type
        )
        
        saveSchedule()
    }
    
    // MARK: - Binding Alternative Application
    
    /// Applies an interruption with a binding executable alternative block
    /// This method ensures the selected alternative is applied as a concrete schedule block,
    /// not just advisory metadata. The alternative becomes part of the actual schedule.
    func applyInterruptWithExecutableAlternative(
        interruptionType: WorkSchedule.InterruptionType,
        interruptionStart: Date,
        interruptionEnd: Date,
        preferredReturnDay: WorkSchedule.Weekday?,
        selectedAlternative: SuggestModeSuggestion
    ) {
        logger.debug("""
        🔒 Applying Binding Alternative:
           Pattern: \(selectedAlternative.workDays)W/\(selectedAlternative.offDays)O
           Interruption: \(interruptionStart, privacy: .public) to \(interruptionEnd, privacy: .public)
           Type: \(interruptionType.rawValue, privacy: .public)
        """)
        
        scheduleEngine.applyInterruptionThenAlternativeBlock(
            &schedule,
            interruptionType: interruptionType,
            interruptionStart: interruptionStart,
            interruptionEnd: interruptionEnd,
            alternativeWorkDays: selectedAlternative.workDays,
            alternativeOffDays: selectedAlternative.offDays
        )
        
        saveSchedule()
    }
    
    // Legacy method kept for backward compatibility (but should not be used in Suggest Mode)
    func applySuggestModeSuggestion(_ suggestion: SuggestModeSuggestion, to schedule: inout WorkSchedule) {
        // This is a stub - the real implementation is in the new method above
        logger.warning("⚠️ Legacy applySuggestModeSuggestion called - this should not be used in Suggest Mode flow")
        saveSchedule()
    }
    
    func markInterruptionDaysOnly(startDate: Date, endDate: Date, type: WorkSchedule.InterruptionType) {
        schedule.isInterrupted = true
        schedule.interruptionStart = startDate
        schedule.interruptionEnd = endDate
        schedule.interruptionType = type
        
        // Mark days as interruption type without rescheduling
        scheduleEngine.markInterruptionDays(&schedule, startDate: startDate, endDate: endDate, type: type)
        
        saveSchedule()
    }
    
    // MARK: - Test Suggest Mode
    
    func testSuggestMode() {
        // Create a test scenario
        let testStartDate = Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date()
        let testEndDate = Calendar.current.date(byAdding: .day, value: 7, to: testStartDate) ?? testStartDate
        let targetReturnDay = WorkSchedule.Weekday.friday
        
        logger.debug("🧠 Testing Suggest Mode with Interruption: \(testStartDate, privacy: .public) to \(testEndDate, privacy: .public), Target Return Day: \(targetReturnDay.description, privacy: .public)")
        
        let result = getSuggestModeResult(
            interruptionStart: testStartDate,
            interruptionEnd: testEndDate,
            interruptionType: .vacation,
            targetReturnDay: targetReturnDay
        )
        
        if let suggestion = result.suggestion {
            logger.debug("""
            ✅ Suggestion Found:
               Type: \(String(describing: suggestion.adjustmentType), privacy: .public)
               Description: \(suggestion.description, privacy: .public)
               Work Days: \(suggestion.workDays)
               Off Days: \(suggestion.offDays)
               Salary Impact: \(suggestion.impactOnSalary ?? "N/A", privacy: .public)
            """)
        } else {
            logger.debug("ℹ️ No suggestion needed - schedule already aligns with target")
        }
        
        if !result.alerts.isEmpty {
            logger.debug("⚠️ Operational Constraints:")
            for alert in result.alerts {
                logger.debug("   \(alert.message, privacy: .public)")
            }
        }
        
        logger.debug("Requires User Approval: \(result.requiresUserApproval, privacy: .public)")
    }
    
    // MARK: - Legacy Methods (for backward compatibility)
    
    /// Legacy method - now calls unified handleInterruption with enhanced mode
    func handleInterruptionWithEnhancedLogic(
        startDate: Date,
        endDate: Date,
        type: WorkSchedule.InterruptionType,
        preferredReturnDay: WorkSchedule.Weekday? = nil
    ) {
        handleInterruption(
            startDate: startDate,
            endDate: endDate,
            type: type,
            preferredReturnDay: preferredReturnDay,
            reschedulingMode: .enhanced
        )
    }
    
    // MARK: - Enhanced Display Methods
    
    func getReschedulePlanPreview(
        interruptionStart: Date,
        interruptionEnd: Date,
        trainingPeriod: DateInterval?,
        preferredReturnDay: WorkSchedule.Weekday?
    ) -> ReschedulePlan? {
        let workDeficit = max(0, 14 - getWorkedDaysBeforeInterruption())
        
        return scheduleEngine.planReschedule(
            interruptionEnd: interruptionEnd,
            trainingPeriod: trainingPeriod,
            targetReturnDay: preferredReturnDay,
            workDeficit: workDeficit
        )
    }
    
    // MARK: - Flexible Rescheduling Methods
    
    /// Creates a preview of flexible reschedule plan
    func getFlexibleReschedulePlanPreview(
        interruptionStart: Date,
        interruptionEnd: Date,
        trainingPeriod: DateInterval?,
        preferredReturnDay: WorkSchedule.Weekday?
    ) -> FlexibleReschedulePlan? {
        let returnDate = Calendar.current.date(byAdding: .day, value: 1, to: interruptionEnd) ?? interruptionEnd
        
        return scheduleEngine.createFlexibleReschedulePlan(
            returnDate: returnDate,
            targetWorkday: preferredReturnDay ?? .monday,
            trainingPeriod: trainingPeriod
        )
    }
    
    /// Legacy method - now calls unified handleInterruption with flexible mode
    func handleInterruptionWithFlexibleRescheduling(
        startDate: Date,
        endDate: Date,
        type: WorkSchedule.InterruptionType,
        preferredReturnDay: WorkSchedule.Weekday? = nil
    ) {
        handleInterruption(
            startDate: startDate,
            endDate: endDate,
            type: type,
            preferredReturnDay: preferredReturnDay,
            reschedulingMode: .flexible
        )
    }
    
    /// Checks if flexible rescheduling is available (not manually adjusted)
    func isFlexibleReschedulingAvailable() -> Bool {
        return !schedule.manuallyAdjusted
    }
    
    /// Gets flexible reschedule plan details for display
    func getFlexibleRescheduleDetails(
        interruptionStart: Date,
        interruptionEnd: Date,
        preferredReturnDay: WorkSchedule.Weekday?
    ) -> String {
        guard let plan = getFlexibleReschedulePlanPreview(
            interruptionStart: interruptionStart,
            interruptionEnd: interruptionEnd,
            trainingPeriod: nil,
            preferredReturnDay: preferredReturnDay
        ) else {
            return "Unable to create flexible reschedule plan."
        }
        
        var details = "Flexible Reschedule Plan:\n"
        details += "• Total Cycles: \(plan.cycles.count)\n"
        details += "• Total Work Days: \(plan.totalWorkDays)\n"
        details += "• Total Off Days: \(plan.totalOffDays)\n"
        details += "• Overall Ratio: \(String(format: "%.1f", plan.overallRatio)):1\n"
        details += "• Return Date: \(DateFormatter.localizedString(from: plan.finalReturnDate, dateStyle: .medium, timeStyle: .none))\n"
        
        for (index, cycle) in plan.cycles.enumerated() {
            details += "• Cycle \(index + 1): \(cycle.workDays) work + \(cycle.offDays) off = \(cycle.totalDays) days\n"
        }
        
        return details
    }
    
    func getTrainingConflicts(
        trainingStart: Date,
        trainingEnd: Date
    ) -> [ConflictInfo] {
        return scheduleEngine.detectTrainingConflicts(
            schedule: schedule,
            trainingStart: trainingStart,
            trainingEnd: trainingEnd
        )
    }
    
    func getZeroEarnedDaysPlan(
        interruptionStart: Date,
        interruptionEnd: Date,
        trainingPeriod: DateInterval?
    ) -> ReschedulePlan {
        return scheduleEngine.handleZeroEarnedDaysScenario(
            interruptionStart: interruptionStart,
            interruptionEnd: interruptionEnd,
            trainingPeriod: trainingPeriod
        )
    }
} 

