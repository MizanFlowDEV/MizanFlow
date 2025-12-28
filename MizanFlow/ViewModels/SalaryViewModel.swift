import Foundation
import SwiftUI

@MainActor
class SalaryViewModel: ObservableObject {
    @Published var salaryBreakdown: SalaryBreakdown
    @Published var selectedMonth: Date = Date()
    @Published var showingAddIncomeSheet = false
    @Published var showingAddDeductionSheet = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let salaryEngine = SalaryEngine.shared
    private let dataService = DataPersistenceService.shared
    private let scheduleEngine = ScheduleEngine.shared
    private let alertService = SmartAlertService.shared
    
    // Store the current schedule
    private var currentSchedule: WorkSchedule?
    
    init(baseSalary: Double = 0) {
        self.salaryBreakdown = SalaryBreakdown(baseSalary: baseSalary, month: Date())
        loadScheduleAndRecalculate(for: Date())
    }
    
    private func loadScheduleAndRecalculate(for month: Date) {
        isLoading = true
        errorMessage = nil
        
        // #region agent log
        let logEntry = "{\"location\":\"SalaryViewModel.swift:26\",\"message\":\"loadScheduleAndRecalculate ENTRY\",\"data\":{\"month\":\"\(month.formatted(date: .abbreviated, time: .omitted))\"},\"timestamp\":\(Int(Date().timeIntervalSince1970*1000)),\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"A,D,E\"}\n"
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
        
        PerformanceMonitor.shared.measure("load_schedule_recalculate") {
            // Try to load all schedules and find the one that contains this month
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: month)
            guard let monthStart = calendar.date(from: components),
                  let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
                errorMessage = "Failed to calculate month boundaries"
                isLoading = false
                AppLogger.viewModel.error("Failed to calculate month boundaries")
                return
            }
            
            // Load or generate schedule
            var schedule: WorkSchedule
            let existingSchedule = dataService.loadLatestSchedule()
            
            // #region agent log
            let logLoad = "{\"location\":\"SalaryViewModel.swift:44\",\"message\":\"loadLatestSchedule result\",\"data\":{\"scheduleExists\":\(existingSchedule != nil),\"hitchStartDate\":\"\(existingSchedule?.hitchStartDate?.formatted(date: .abbreviated, time: .omitted) ?? "nil")\",\"scheduleId\":\"\(existingSchedule?.id.uuidString ?? "nil")\"},\"timestamp\":\(Int(Date().timeIntervalSince1970*1000)),\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"A,C,E\"}\n"
            if let data = logLoad.data(using: .utf8) {
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
            
            if let existingSchedule = existingSchedule,
               existingSchedule.hitchStartDate != nil {
                schedule = existingSchedule
                
                // #region agent log
                let logExisting = "{\"location\":\"SalaryViewModel.swift:46\",\"message\":\"Using existing schedule\",\"data\":{\"hitchStartDate\":\"\(schedule.hitchStartDate?.formatted(date: .abbreviated, time: .omitted) ?? "nil")\",\"scheduleId\":\"\(schedule.id.uuidString)\"},\"timestamp\":\(Int(Date().timeIntervalSince1970*1000)),\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"A\"}\n"
                if let data = logExisting.data(using: .utf8) {
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
                
                // Recalculate overtime hours for existing schedule to fix any incorrect values
                scheduleEngine.recalculateOvertimeHours(&schedule)
                // Save the corrected schedule
                dataService.saveSchedule(schedule)
                
                // Check if the selected month is outside the schedule's date range
                // If so, extend the schedule to include it
                if monthStart < schedule.startDate || monthEnd > schedule.endDate {
                    // Determine the new start date (use the earlier of current start or selected month)
                    let newStartDate = min(schedule.startDate, monthStart)
                    // Determine how many months we need to cover
                    let monthsToGenerate = max(
                        calendar.dateComponents([.month], from: newStartDate, to: monthEnd).month ?? 12,
                        12
                    ) + 1 // Add 1 to ensure we cover the full range
                    
                    // Regenerate schedule from the new start date
                    schedule = scheduleEngine.generateSchedule(from: newStartDate, for: monthsToGenerate, hitchStartDate: existingSchedule.hitchStartDate)
                    // Preserve the hitch start date
                    schedule.hitchStartDate = existingSchedule.hitchStartDate
                    // Preserve other important properties
                    schedule.isInterrupted = existingSchedule.isInterrupted
                    schedule.interruptionStart = existingSchedule.interruptionStart
                    schedule.interruptionEnd = existingSchedule.interruptionEnd
                    schedule.interruptionType = existingSchedule.interruptionType
                    schedule.vacationBalance = existingSchedule.vacationBalance
                    
                    // Save the extended schedule
                    dataService.saveSchedule(schedule)
                }
            } else {
                // #region agent log
                let logNew = "{\"location\":\"SalaryViewModel.swift:78\",\"message\":\"FALLING INTO ELSE - no schedule or no hitchStartDate\",\"data\":{\"existingSchedule\":\(existingSchedule != nil),\"hitchStartDateIsNil\":\(existingSchedule?.hitchStartDate == nil)},\"timestamp\":\(Int(Date().timeIntervalSince1970*1000)),\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"A,E\"}\n"
                if let data = logNew.data(using: .utf8) {
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
                
                // If no valid schedule found or no hitch start date, we cannot generate a schedule
                // The user must set the hitch start date first in the Schedule view
                errorMessage = "Please set the Hitch Start Date in the Schedule view first"
                isLoading = false
                AppLogger.viewModel.warning("Cannot generate schedule: no hitch start date set")
                return
            }
            
            self.currentSchedule = schedule
            
            // Recalculate salary breakdown for the selected month
            let newBreakdown = salaryEngine.calculateSalary(for: schedule, baseSalary: salaryBreakdown.baseSalary, month: monthStart)
            
            // DIAGNOSTIC: Run diagnostics to identify issues
            #if DEBUG
            let diagnostics = SalaryDiagnostics.shared
            let report = diagnostics.diagnoseOvertimeCalculation(for: schedule, month: monthStart)
            report.printReport()
            #endif
            
            // Update the salary breakdown - preserve user inputs but update calculated values and month
            salaryBreakdown.month = monthStart
            salaryBreakdown.overtimeHours = newBreakdown.overtimeHours
            salaryBreakdown.adlHours = newBreakdown.adlHours
            
            isLoading = false
            
            // Force UI update by triggering objectWillChange
            objectWillChange.send()
        }
    }
    
    func saveSalary(triggerHaptics: Bool = true) {
        dataService.saveSalaryBreakdown(salaryBreakdown)
        if triggerHaptics {
            HapticFeedback.saveSuccess()
        }
    }
    
    func updateBaseSalary(_ newSalary: Double) {
        let validation = ValidationUtilities.validateSalary(newSalary)
        guard validation.isValid else {
            // In a real app, show error to user
            AppLogger.viewModel.warning("Invalid salary: \(validation.errorMessage ?? "Unknown error", privacy: .public)")
            return
        }
        salaryBreakdown.baseSalary = newSalary
        saveSalary()
        checkSalaryChanges()
    }
    
    func updateMonth(_ newMonth: Date) {
        selectedMonth = newMonth
        loadScheduleAndRecalculate(for: newMonth)
        saveSalary()
    }
    
    func addAdditionalIncome(description: String, amount: Double, notes: String? = nil) {
        let descriptionValidation = ValidationUtilities.validateNonEmptyString(description, fieldName: NSLocalizedString("Description", comment: "Description field"))
        let amountValidation = ValidationUtilities.validateAmount(amount)
        
        guard descriptionValidation.isValid && amountValidation.isValid else {
            AppLogger.viewModel.warning("Invalid income entry: \(descriptionValidation.errorMessage ?? amountValidation.errorMessage ?? "Unknown error", privacy: .public)")
            return
        }
        
        let sanitizedDescription = ValidationUtilities.sanitizeString(description)
        let sanitizedNotes = notes.map { ValidationUtilities.sanitizeString($0) }
        
        salaryEngine.addAdditionalIncome(&salaryBreakdown, description: sanitizedDescription, amount: amount, notes: sanitizedNotes)
        saveSalary()
        checkSalaryChanges()
    }
    
    func addCustomDeduction(description: String, amount: Double, notes: String? = nil) {
        let descriptionValidation = ValidationUtilities.validateNonEmptyString(description, fieldName: NSLocalizedString("Description", comment: "Description field"))
        let amountValidation = ValidationUtilities.validateAmount(amount)
        
        guard descriptionValidation.isValid && amountValidation.isValid else {
            AppLogger.viewModel.warning("Invalid deduction entry: \(descriptionValidation.errorMessage ?? amountValidation.errorMessage ?? "Unknown error", privacy: .public)")
            return
        }
        
        let sanitizedDescription = ValidationUtilities.sanitizeString(description)
        let sanitizedNotes = notes.map { ValidationUtilities.sanitizeString($0) }
        
        salaryEngine.addCustomDeduction(&salaryBreakdown, description: sanitizedDescription, amount: amount, notes: sanitizedNotes)
        saveSalary()
        checkSalaryChanges()
    }
    
    func updateDeductionPercentages(homeLoan: Double, espp: Double) {
        let homeLoanValidation = ValidationUtilities.validateHomeLoanPercentage(homeLoan)
        let esppValidation = ValidationUtilities.validateESPPPercentage(espp)
        
        guard homeLoanValidation.isValid && esppValidation.isValid else {
            AppLogger.viewModel.warning("Invalid deduction percentages: \(homeLoanValidation.errorMessage ?? esppValidation.errorMessage ?? "Unknown error", privacy: .public)")
            return
        }
        
        salaryEngine.updateDeductionPercentages(&salaryBreakdown, homeLoan: homeLoan, espp: espp)
        saveSalary()
        checkSalaryChanges()
    }
    
    // Silent update for slider - updates values without haptics
    func updateDeductionPercentagesSilently(homeLoan: Double, espp: Double) {
        let homeLoanValidation = ValidationUtilities.validateHomeLoanPercentage(homeLoan)
        let esppValidation = ValidationUtilities.validateESPPPercentage(espp)
        
        guard homeLoanValidation.isValid && esppValidation.isValid else {
            return
        }
        
        salaryEngine.updateDeductionPercentages(&salaryBreakdown, homeLoan: homeLoan, espp: espp)
        // Save without haptics - haptics handled in view at thresholds
        saveSalary(triggerHaptics: false)
    }
    
    func updateSpecialOperationsPercentage(_ percentage: Double) {
        let validation = ValidationUtilities.validateSpecialOperationsPercentage(percentage)
        guard validation.isValid else {
            AppLogger.viewModel.warning("Invalid special operations percentage: \(validation.errorMessage ?? "Unknown error", privacy: .public)")
            return
        }
        salaryEngine.updateSpecialOperationsPercentage(&salaryBreakdown, percentage: percentage)
        saveSalary()
        checkSalaryChanges()
    }
    
    private func checkSalaryChanges() {
        // In a real app, you would compare with the previous month's salary
        // For now, we'll just check if the current salary is significantly different from the base
        // Using underscore to silence the unused variable warning
        _ = ((salaryBreakdown.totalCompensation - salaryBreakdown.baseSalary) / salaryBreakdown.baseSalary) * 100
        alertService.checkSalaryChanges(salaryBreakdown.totalCompensation, previousSalary: salaryBreakdown.baseSalary)
    }
    
    // MARK: - Formatting Methods
    
    func formatCurrency(_ amount: Double) -> String {
        return FormattingUtilities.formatCurrency(amount)
    }
    
    func formatPercentage(_ value: Double) -> String {
        return FormattingUtilities.formatPercentage(value)
    }
    
    func formatMonth(_ date: Date) -> String {
        return FormattingUtilities.formatMonth(date)
    }
    
    // MARK: - Calculation Methods
    
    var totalAllowances: Double {
        salaryBreakdown.totalAllowances
    }
    
    var totalDeductions: Double {
        salaryBreakdown.totalDeductions
    }
    
    var totalCompensation: Double {
        salaryBreakdown.totalCompensation
    }
    
    var netPay: Double {
        salaryBreakdown.netPay
    }
    
    var overtimePay: Double {
        salaryBreakdown.overtimePay
    }
    
    var adlPay: Double {
        salaryBreakdown.adlPay
    }
    
    var remoteAllowance: Double {
        salaryBreakdown.remoteAllowance
    }
    
    var specialOperationsAllowance: Double {
        salaryBreakdown.specialOperationsAllowance
    }
    
    var transportationAllowance: Double {
        salaryBreakdown.transportationAllowance
    }
    
    var homeLoanDeduction: Double {
        salaryBreakdown.homeLoanDeduction
    }
    
    var esppDeduction: Double {
        salaryBreakdown.esppDeduction
    }
    
    var gosiDeduction: Double {
        salaryBreakdown.gosiDeduction
    }
    
    var sanidDeduction: Double {
        salaryBreakdown.sanidDeduction
    }
} 