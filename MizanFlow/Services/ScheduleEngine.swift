import Foundation

// MARK: - Suggest Mode with Operational Constraints
struct SuggestModeResult {
    let suggestion: SuggestModeSuggestion?
    let alerts: [OperationalAlert]
    let requiresUserApproval: Bool
    let alternatives: [SuggestModeSuggestion] // FIXED: Add alternatives when warnings detected
}

struct SuggestModeSuggestion {
    let adjustmentType: AdjustmentType
    let workDays: Int
    let offDays: Int
    let totalDays: Int
    let targetReturnDay: WorkSchedule.Weekday
    let description: String
    let impactOnSalary: String?
    
    // NEW: Warning-based rescheduling properties
    let validationWarnings: [String] // Immediate pattern warnings
    let futureSimulationWarnings: [String] // Future 14W/7O alignment warnings
    let score: Double // Calculated priority score (higher = better)
    let isRecommended: Bool // True if no warnings in either phase
    
    // Convenience initializer with defaults for backward compatibility
    init(
        adjustmentType: AdjustmentType,
        workDays: Int,
        offDays: Int,
        totalDays: Int,
        targetReturnDay: WorkSchedule.Weekday,
        description: String,
        impactOnSalary: String?,
        validationWarnings: [String] = [],
        futureSimulationWarnings: [String] = [],
        score: Double = 0.0,
        isRecommended: Bool = true
    ) {
        self.adjustmentType = adjustmentType
        self.workDays = workDays
        self.offDays = offDays
        self.totalDays = totalDays
        self.targetReturnDay = targetReturnDay
        self.description = description
        self.impactOnSalary = impactOnSalary
        self.validationWarnings = validationWarnings
        self.futureSimulationWarnings = futureSimulationWarnings
        self.score = score
        self.isRecommended = isRecommended
    }
}

enum AdjustmentType {
    case minorAdjustment
    case moderateAdjustment
    case cycleReconstruction
}

struct OperationalAlert {
    let type: AlertType
    let message: String
    let requiresApproval: Bool
}

enum AlertType {
    case workdaysTooShort
    case workdaysTooLong
    case trainingOnOffDay
    case cycleReconstruction
}

// MARK: - Flexible Rescheduling Data Structures
struct FlexibleCycle {
    let workDays: Int
    let offDays: Int
    
    var totalDays: Int {
        return workDays + offDays
    }
    
    var isValid: Bool {
        return workDays > 0 && offDays > 0 && workDays <= 14 && offDays <= 7
    }
}

struct FlexibleReschedulePlan {
    let cycles: [FlexibleCycle]
    let finalReturnDate: Date
    let totalWorkDays: Int
    let totalOffDays: Int
    let trainingAccommodated: Bool
    
    var isValid: Bool {
        return !cycles.isEmpty && cycles.allSatisfy { $0.isValid } && totalWorkDays > 0 && totalOffDays > 0
    }
    
    var totalDays: Int {
        return cycles.reduce(0) { $0 + $1.totalDays }
    }
    
    var overallRatio: Double {
        return totalOffDays > 0 ? Double(totalWorkDays) / Double(totalOffDays) : 0
    }
}

// MARK: - Legacy Data Structures (Preserved for backward compatibility)
struct ReschedulePlan {
    let workPeriods: [(start: Date, end: Date, days: Int)]
    let offPeriods: [(start: Date, end: Date, days: Int)]
    let trainingPlacement: DateInterval?
    let finalReturnDate: Date
    let totalWorkDays: Int
    let totalOffDays: Int
    let earnedDaysGenerated: Int
    
    var isValid: Bool {
        return totalWorkDays > 0 && totalOffDays > 0 && 
               abs(totalWorkDays - totalOffDays * 2) <= 1 // Allow 2:1 ratio flexibility
    }
}

struct ConflictInfo {
    let conflictType: ConflictType
    let conflictDate: Date
    let suggestedResolution: ReschedulePlan?
    let impactAssessment: String
}

enum ConflictType {
    case trainingOnOffDay
    case insufficientEarnedDays
    case crewChangeMisalignment
}

class ScheduleEngine {
    static let shared = ScheduleEngine()
    private let holidayService = HolidayService.shared
    private init() {}
    
    // MARK: - Date Normalization Helpers
    
    /// Normalizes any date to start of day for consistent comparisons
    private func normalizeToStartOfDay(_ date: Date) -> Date {
        return Calendar.current.startOfDay(for: date)
    }
    
    /// Computes the next standard 14W/7O hitch start date after applying a suggestion block.
    /// This is the source-of-truth helper that both analyzer and applier must use.
    /// Rule: resumeDate = startOfDay(interruptionEnd + 1 day)
    ///       suggestionBlockLength = workDays + offDays
    ///       nextStandardStart = startOfDay(resumeDate + suggestionBlockLength days)
    /// IMPORTANT: No extra +1 anywhere. This must exactly match how applySuggestModeSuggestion resumes baseline.
    private func nextStandardHitchStartDate(
        interruptionEnd: Date,
        suggestionWorkDays: Int,
        suggestionOffDays: Int,
        calendar: Calendar
    ) -> Date {
        let end = calendar.startOfDay(for: interruptionEnd)
        let resume = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        let total = suggestionWorkDays + suggestionOffDays
        // The standard hitch restarts the day AFTER the suggestion block ends.
        // If suggestion block starts on resume and lasts 'total' days,
        // then next standard start = resume + total (NO extra +1 anywhere).
        let nextStart = calendar.date(byAdding: .day, value: total, to: resume) ?? resume
        return calendar.startOfDay(for: nextStart)
    }
    
    /// Safely checks if a date is within a range (inclusive) using normalized dates
    private func isDateInRange(_ date: Date, start: Date, end: Date) -> Bool {
        let normalizedDate = normalizeToStartOfDay(date)
        let normalizedStart = normalizeToStartOfDay(start)
        let normalizedEnd = normalizeToStartOfDay(end)
        return normalizedDate >= normalizedStart && normalizedDate <= normalizedEnd
    }
    
    /// Gets all days in a date range (inclusive) as an array of dates
    private func getDaysInRange(start: Date, end: Date) -> [Date] {
        var days: [Date] = []
        let calendar = Calendar.current
        let normalizedStart = normalizeToStartOfDay(start)
        let normalizedEnd = normalizeToStartOfDay(end)
        
        var currentDate = normalizedStart
        while currentDate <= normalizedEnd {
            days.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
        
        return days
    }
    
    // MARK: - Suggest Mode Validation & Simulation Helpers
    
    /// Validates a suggestion against operational constraints and returns warnings
    private func validateSuggestion(
        workDays: Int,
        offDays: Int,
        schedule: WorkSchedule,
        interruptionEnd: Date
    ) -> [String] {
        var warnings: [String] = []
        
        // Check minimum work days
        if workDays < 5 {
            warnings.append("Work period is too short (\(workDays) days). Minimum 5 days recommended for travel and scheduling.")
        }
        
        // Check maximum work days
        if workDays > 14 {
            warnings.append("Work period exceeds standard 14-day cycle (\(workDays) days). Supervisor approval may be required.")
        }
        
        // Check minimum off days
        if offDays < 2 {
            warnings.append("Off period is too short (\(offDays) days). Minimum 2 days recommended for rest.")
        }
        
        // Check work/off ratio
        if let ratioError = checkWorkOffRatio(workDays: workDays, offDays: offDays) {
            warnings.append("Work/off ratio concern: \(ratioError)")
        }
        
        // Check if cycle length is unusual
        let totalDays = workDays + offDays
        if totalDays < 7 || totalDays > 25 {
            warnings.append("Unusual cycle length (\(totalDays) days). Standard is 21 days (14W/7O).")
        }
        
        return warnings
    }
    
    /// Simulates future 14W/7O alignment and returns warnings if misalignment detected
    private func simulateFutureAlignment(
        workDays: Int,
        offDays: Int,
        schedule: WorkSchedule,
        interruptionEnd: Date,
        targetReturnDay: WorkSchedule.Weekday
    ) -> [String] {
        var warnings: [String] = []
        let calendar = Calendar.current
        let returnDate = calendar.date(byAdding: .day, value: 1, to: interruptionEnd) ?? interruptionEnd
        
        // Calculate when the next standard 14W/7O cycle would start
        let totalCycleDays = workDays + offDays
        _ = calendar.date(byAdding: .day, value: totalCycleDays, to: returnDate) ?? returnDate
        
        // Check if the next cycle start aligns with standard pattern
        // Standard pattern: 14 work days, 7 off days = 21 days total
        let standardCycle = 21
        
        // Calculate how many standard cycles we're offset
        let daysOffset = totalCycleDays % standardCycle
        if daysOffset != 0 {
            warnings.append("This adjustment will shift the schedule by \(daysOffset) days from standard 14W/7O pattern. Future cycles may require additional adjustments.")
        }
        
        // Check if work/off ratio deviates significantly from 2:1
        let ratio = Double(workDays) / Double(offDays)
        let standardRatio = 14.0 / 7.0 // 2:1
        let ratioDeviation = abs(ratio - standardRatio)
        
        if ratioDeviation > 0.5 {
            warnings.append("Work/off ratio (\(String(format: "%.1f", ratio)):1) deviates significantly from standard 2:1. This may affect future schedule alignment.")
        }
        
        // Check if this will create a pattern that's hard to return to standard
        if workDays != 14 || offDays != 7 {
            // Calculate how many cycles needed to return to standard
            let cyclesToReturn = calculateCyclesToReturnToStandard(
                currentWorkDays: workDays,
                currentOffDays: offDays
            )
            
            if cyclesToReturn > 2 {
                warnings.append("This adjustment may require \(cyclesToReturn) additional cycles to return to standard 14W/7O pattern.")
            }
        }
        
        return warnings
    }
    
    /// Calculates how many cycles are needed to return to standard 14W/7O pattern
    private func calculateCyclesToReturnToStandard(currentWorkDays: Int, currentOffDays: Int) -> Int {
        // This is a simplified calculation
        // In reality, we'd need to simulate multiple cycles forward
        let currentTotal = currentWorkDays + currentOffDays
        let standardTotal = 21
        
        // Find LCM or calculate cycles needed
        if currentTotal == standardTotal {
            return 0
        }
        
        // Simple heuristic: if total days don't match, it will take multiple cycles
        let difference = abs(currentTotal - standardTotal)
        if difference == 0 {
            return 0
        } else if difference <= 3 {
            return 1
        } else if difference <= 7 {
            return 2
        } else {
            return 3
        }
    }
    
    /// Calculates a score for a suggestion based on warnings, ratios, and alignment
    /// - Parameters:
    ///   - workDays: Work days in the cycle
    ///   - offDays: Off days in the cycle
    ///   - validationWarnings: Immediate validation warnings
    ///   - futureSimulationWarnings: Future alignment warnings
    ///   - adjustmentType: Type of adjustment
    ///   - alignsWithTargetReturnDay: Whether this cycle aligns the next 14W/7O restart with target return day
    private func calculateSuggestionScore(
        workDays: Int,
        offDays: Int,
        validationWarnings: [String],
        futureSimulationWarnings: [String],
        adjustmentType: AdjustmentType,
        alignsWithTargetReturnDay: Bool = false
    ) -> Double {
        // FIXED: Start lower to allow proper differentiation between alternatives
        var score = 70.0
        
        // Deduct points for validation warnings (more severe)
        score -= Double(validationWarnings.count) * 20.0
        
        // Deduct points for future simulation warnings (less severe but still important)
        score -= Double(futureSimulationWarnings.count) * 15.0
        
        // PART 2: Bonus for aligning next 14W/7O restart with target return day (HIGHEST PRIORITY)
        if alignsWithTargetReturnDay {
            score += 50.0 // Highest priority bonus for alignment
        }
        
        // Bonus for standard 14W/7O pattern
        if workDays == 14 && offDays == 7 {
            score += 30.0
        }
        
        // Bonus for minor adjustments (preferred)
        switch adjustmentType {
        case .minorAdjustment:
            score += 10.0
        case .moderateAdjustment:
            score += 5.0
        case .cycleReconstruction:
            score -= 15.0 // Penalty for major changes
        }
        
        // Bonus for good work/off ratio (close to 2:1)
        let ratio = Double(workDays) / Double(offDays)
        let standardRatio = 2.0
        let ratioDeviation = abs(ratio - standardRatio)
        if ratioDeviation < 0.2 {
            score += 10.0
        } else if ratioDeviation < 0.5 {
            score += 5.0
        } else {
            score -= Double(ratioDeviation) * 8.0
        }
        
        // Ensure score is within reasonable bounds
        return max(0.0, min(100.0, score))
    }
    
    /// Generates alternative suggestions when warnings are detected
    /// ENHANCED: Now prioritizes cycles that align the next 14W/7O restart with target return day
    private func generateAlternatives(
        schedule: WorkSchedule,
        interruptionEnd: Date,
        targetReturnDay: WorkSchedule.Weekday,
        workedDays: Int,
        earnedDays: Int,
        originalSuggestion: SuggestModeSuggestion
    ) -> [SuggestModeSuggestion] {
        var alternatives: [SuggestModeSuggestion] = []
        let calendar = Calendar.current
        
        // FIXED: Use allowed cycle set (no hardcoded "bad" cycles like 8/3)
        let allowedCycles = [
            (workDays: 14, offDays: 7),  // Baseline standard
            (workDays: 13, offDays: 7),
            (workDays: 12, offDays: 6),
            (workDays: 11, offDays: 6),
            (workDays: 10, offDays: 5),
            (workDays: 9, offDays: 5),
            (workDays: 8, offDays: 4),   // FIXED: 8W/4O not 8W/3O
            (workDays: 7, offDays: 4),
            (workDays: 6, offDays: 3),
            (workDays: 5, offDays: 3),
            (workDays: 3, offDays: 2),  // Allowed but Not Recommended
            (workDays: 2, offDays: 1),  // Allowed but Not Recommended
        ]
        
        // ENHANCED: Generate candidates and check which ones align next 14W/7O restart with target return day
        for cycle in allowedCycles {
            let totalDays = cycle.workDays + cycle.offDays
            
            // Skip if identical to original suggestion
            if cycle.workDays == originalSuggestion.workDays && cycle.offDays == originalSuggestion.offDays {
                continue
            }
            
            // PART 2: Use the source-of-truth helper to compute next standard hitch start date
            let nextStandardStart = nextStandardHitchStartDate(
                interruptionEnd: interruptionEnd,
                suggestionWorkDays: cycle.workDays,
                suggestionOffDays: cycle.offDays,
                calendar: calendar
            )
            let nextCycleStartWeekday = calendar.component(.weekday, from: nextStandardStart)
            let nextCycleStartDay = WorkSchedule.Weekday(rawValue: nextCycleStartWeekday) ?? .monday
            
            // Check if this cycle aligns the next 14W/7O restart with target return day
            let alignsWithTarget = (nextCycleStartDay == targetReturnDay)
            
            // PART 2: Debug log for each alternative
            print("ALT \(cycle.workDays)W/\(cycle.offDays)O -> next14/7Start=\(nextStandardStart) weekday=\(nextCycleStartDay.description) aligns=\(alignsWithTarget)")
            
            // Validate this alternative
            let validationWarnings = validateSuggestion(
                workDays: cycle.workDays,
                offDays: cycle.offDays,
                schedule: schedule,
                interruptionEnd: interruptionEnd
            )
            
            let futureWarnings = simulateFutureAlignment(
                workDays: cycle.workDays,
                offDays: cycle.offDays,
                schedule: schedule,
                interruptionEnd: interruptionEnd,
                targetReturnDay: targetReturnDay
            )
            
            // ENHANCED: Pass alignment info to scoring
            let score = calculateSuggestionScore(
                workDays: cycle.workDays,
                offDays: cycle.offDays,
                validationWarnings: validationWarnings,
                futureSimulationWarnings: futureWarnings,
                adjustmentType: cycle.workDays == 14 && cycle.offDays == 7 ? .minorAdjustment : .moderateAdjustment,
                alignsWithTargetReturnDay: alignsWithTarget
            )
            
            let isRecommended = validationWarnings.isEmpty && futureWarnings.isEmpty && alignsWithTarget
            
            // PART 2: Update description to show alignment status - only if actually aligned
            var description = "Alternative: \(cycle.workDays)W/\(cycle.offDays)O"
            if alignsWithTarget {
                // Use description property which returns localized name
                let targetDayName = targetReturnDay.description
                description += " (aligns next 14W/7O with \(targetDayName))"
            }
            
            let alternative = SuggestModeSuggestion(
                adjustmentType: cycle.workDays == 14 && cycle.offDays == 7 ? .minorAdjustment : .moderateAdjustment,
                workDays: cycle.workDays,
                offDays: cycle.offDays,
                totalDays: totalDays,
                targetReturnDay: targetReturnDay,
                description: description,
                impactOnSalary: calculateSalaryImpact(workDays: cycle.workDays, offDays: cycle.offDays),
                validationWarnings: validationWarnings,
                futureSimulationWarnings: futureWarnings,
                score: score,
                isRecommended: isRecommended
            )
            
            alternatives.append(alternative)
        }
        
        // Remove duplicates based on workDays/offDays combination
        var seen = Set<String>()
        alternatives = alternatives.filter { alt in
            let key = "\(alt.workDays)-\(alt.offDays)"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
        
        // PART 2: Sort by alignment with target return day first, then by score
        // Calculate alignment for each alternative using the same helper
        let alternativesWithAlignment = alternatives.map { alt -> (alt: SuggestModeSuggestion, aligns: Bool) in
            let nextStandardStart = nextStandardHitchStartDate(
                interruptionEnd: interruptionEnd,
                suggestionWorkDays: alt.workDays,
                suggestionOffDays: alt.offDays,
                calendar: calendar
            )
            let nextCycleStartWeekday = calendar.component(.weekday, from: nextStandardStart)
            let nextCycleStartDay = WorkSchedule.Weekday(rawValue: nextCycleStartWeekday) ?? .monday
            let aligns = (nextCycleStartDay == targetReturnDay)
            return (alt, aligns)
        }
        
        let sorted = alternativesWithAlignment.sorted { first, second in
            // First priority: alignment with target return day
            if first.aligns != second.aligns {
                return first.aligns // Prefer aligned alternatives
            }
            // Second priority: fewer warnings
            let firstWarnings = first.alt.validationWarnings.count + first.alt.futureSimulationWarnings.count
            let secondWarnings = second.alt.validationWarnings.count + second.alt.futureSimulationWarnings.count
            if firstWarnings != secondWarnings {
                return firstWarnings < secondWarnings
            }
            // Third priority: score
            return first.alt.score > second.alt.score
        }
        return Array(sorted.map { $0.alt }.prefix(4))
    }
    
    // MARK: - Suggest Mode with Operational Constraints
    
    /// Implements the updated Suggest Mode logic with operational constraints
    /// - Parameters:
    ///   - schedule: Current work schedule
    ///   - interruptionStart: Start date of interruption
    ///   - interruptionEnd: End date of interruption
    ///   - interruptionType: Type of interruption
    ///   - targetReturnDay: Desired return day (Sunday-Friday)
    /// - Returns: SuggestModeResult with suggestion and alerts
    func suggestModeWithOperationalConstraints(
        schedule: WorkSchedule,
        interruptionStart: Date,
        interruptionEnd: Date,
        interruptionType: WorkSchedule.InterruptionType,
        targetReturnDay: WorkSchedule.Weekday
    ) -> SuggestModeResult {
        
        // Step 1: Input Data - Already provided as parameters
        
        // Step 2: Analyse Current Schedule
        let (workedDays, earnedDays) = calculateWorkedAndEarnedDaysBeforeInterruption(schedule, interruptionStart: interruptionStart)
        let currentReturnDay = calculateCurrentReturnDay(schedule: schedule, interruptionEnd: interruptionEnd)
        
        // Check if current return day matches target
        if currentReturnDay == targetReturnDay {
            return SuggestModeResult(
                suggestion: nil,
                alerts: [],
                requiresUserApproval: false,
                alternatives: []
            )
        }
        
        // Step 3: Adjustment Decision Process
        var alerts: [OperationalAlert] = []
        
        // Level 1: Minor Adjustment (±3 days)
        if let minorSuggestion = attemptMinorAdjustment(
            schedule: schedule,
            interruptionEnd: interruptionEnd,
            targetReturnDay: targetReturnDay,
            workedDays: workedDays,
            earnedDays: earnedDays,
            alerts: &alerts
        ) {
            // Generate alternatives if warnings exist
            let alternatives = (!minorSuggestion.validationWarnings.isEmpty || !minorSuggestion.futureSimulationWarnings.isEmpty) ?
                generateAlternatives(
                    schedule: schedule,
                    interruptionEnd: interruptionEnd,
                    targetReturnDay: targetReturnDay,
                    workedDays: workedDays,
                    earnedDays: earnedDays,
                    originalSuggestion: minorSuggestion
                ) : []
            
            return SuggestModeResult(
                suggestion: minorSuggestion,
                alerts: alerts,
                requiresUserApproval: !alerts.isEmpty || !minorSuggestion.validationWarnings.isEmpty || !minorSuggestion.futureSimulationWarnings.isEmpty,
                alternatives: alternatives
            )
        }
        
        // Level 2: Moderate Adjustment (Variable Cycle Length)
        if let moderateSuggestion = attemptModerateAdjustment(
            schedule: schedule,
            interruptionEnd: interruptionEnd,
            targetReturnDay: targetReturnDay,
            workedDays: workedDays,
            earnedDays: earnedDays,
            alerts: &alerts
        ) {
            // Generate alternatives if warnings exist
            let alternatives = (!moderateSuggestion.validationWarnings.isEmpty || !moderateSuggestion.futureSimulationWarnings.isEmpty) ?
                generateAlternatives(
                    schedule: schedule,
                    interruptionEnd: interruptionEnd,
                    targetReturnDay: targetReturnDay,
                    workedDays: workedDays,
                    earnedDays: earnedDays,
                    originalSuggestion: moderateSuggestion
                ) : []
            
            return SuggestModeResult(
                suggestion: moderateSuggestion,
                alerts: alerts,
                requiresUserApproval: !alerts.isEmpty || !moderateSuggestion.validationWarnings.isEmpty || !moderateSuggestion.futureSimulationWarnings.isEmpty,
                alternatives: alternatives
            )
        }
        
        // Level 3: Last Resort (Cycle Reconstruction)
        let reconstructionSuggestion = attemptCycleReconstruction(
            schedule: schedule,
            interruptionEnd: interruptionEnd,
            targetReturnDay: targetReturnDay,
            workedDays: workedDays,
            earnedDays: earnedDays
        )
        
        alerts.append(OperationalAlert(
            type: .cycleReconstruction,
            message: "This proposal will create a new cycle to ensure the desired return day. It may alter upcoming work/off sequences. Do you wish to continue?",
            requiresApproval: true
        ))
        
        // Always generate alternatives for cycle reconstruction
        let alternatives = generateAlternatives(
            schedule: schedule,
            interruptionEnd: interruptionEnd,
            targetReturnDay: targetReturnDay,
            workedDays: workedDays,
            earnedDays: earnedDays,
            originalSuggestion: reconstructionSuggestion
        )
        
        return SuggestModeResult(
            suggestion: reconstructionSuggestion,
            alerts: alerts,
            requiresUserApproval: true,
            alternatives: alternatives
        )
    }
    
    // MARK: - Suggest Mode Helper Functions
    
    private func calculateCurrentReturnDay(schedule: WorkSchedule, interruptionEnd: Date) -> WorkSchedule.Weekday {
        let calendar = Calendar.current
        let returnDate = calendar.date(byAdding: .day, value: 1, to: interruptionEnd) ?? interruptionEnd
        
        // Calculate what day of the week the return would be based on current schedule
        let weekday = calendar.component(.weekday, from: returnDate)
        return WorkSchedule.Weekday(rawValue: weekday) ?? .monday
    }
    
    private func attemptMinorAdjustment(
        schedule: WorkSchedule,
        interruptionEnd: Date,
        targetReturnDay: WorkSchedule.Weekday,
        workedDays: Int,
        earnedDays: Int,
        alerts: inout [OperationalAlert]
    ) -> SuggestModeSuggestion? {
        let calendar = Calendar.current
        let returnDate = calendar.date(byAdding: .day, value: 1, to: interruptionEnd) ?? interruptionEnd
        
        // Try shifting by ±3 days
        for shift in -3...3 {
            if shift == 0 { continue }
            
            let adjustedReturnDate = calendar.date(byAdding: .day, value: shift, to: returnDate) ?? returnDate
            let adjustedWeekday = calendar.component(.weekday, from: adjustedReturnDate)
            
            if WorkSchedule.Weekday(rawValue: adjustedWeekday) == targetReturnDay {
                let workDays = min(14, max(0, workedDays + shift))
                let offDays = max(2, min(7, earnedDays + (shift > 0 ? 1 : -1)))
                
                // Enhanced validation checks
                if workDays < 5 {
                    alerts.append(OperationalAlert(
                        type: .workdaysTooShort,
                        message: "The proposed cycle is too short (only \(workDays) workdays), which may make travel and scheduling impractical. Proceed anyway?",
                        requiresApproval: true
                    ))
                }
                
                if workDays > 14 {
                    alerts.append(OperationalAlert(
                        type: .workdaysTooLong,
                        message: "This proposal exceeds the standard 14-day work cycle. It usually requires supervisor approval. Continue anyway?",
                        requiresApproval: true
                    ))
                }
                
                // Check minimum off days
                if offDays < 2 {
                    alerts.append(OperationalAlert(
                        type: .workdaysTooShort,
                        message: "The proposed cycle has only \(offDays) off days, which is below the minimum of 2. Proceed anyway?",
                        requiresApproval: true
                    ))
                }
                
                // Check work/off ratio
                if let ratioError = checkWorkOffRatio(workDays: workDays, offDays: offDays) {
                    alerts.append(OperationalAlert(
                        type: .workdaysTooShort,
                        message: "The proposed cycle has an unusual work/off ratio. \(ratioError) Proceed anyway?",
                        requiresApproval: true
                    ))
                }
                
                // Validate and simulate
                let validationWarnings = validateSuggestion(
                    workDays: workDays,
                    offDays: offDays,
                    schedule: schedule,
                    interruptionEnd: interruptionEnd
                )
                
                let futureWarnings = simulateFutureAlignment(
                    workDays: workDays,
                    offDays: offDays,
                    schedule: schedule,
                    interruptionEnd: interruptionEnd,
                    targetReturnDay: targetReturnDay
                )
                
                // Check if this suggestion aligns with target return day
                let totalDays = workDays + offDays
                let cycleEndDate = calendar.date(byAdding: .day, value: totalDays, to: returnDate) ?? returnDate
                let nextStandardCycleStart = calendar.date(byAdding: .day, value: 1, to: cycleEndDate) ?? cycleEndDate
                let nextCycleStartWeekday = calendar.component(.weekday, from: nextStandardCycleStart)
                let nextCycleStartDay = WorkSchedule.Weekday(rawValue: nextCycleStartWeekday) ?? .monday
                let alignsWithTarget = (nextCycleStartDay == targetReturnDay)
                
                let score = calculateSuggestionScore(
                    workDays: workDays,
                    offDays: offDays,
                    validationWarnings: validationWarnings,
                    futureSimulationWarnings: futureWarnings,
                    adjustmentType: .minorAdjustment,
                    alignsWithTargetReturnDay: alignsWithTarget
                )
                
                let isRecommended = validationWarnings.isEmpty && futureWarnings.isEmpty && alignsWithTarget
                
                return SuggestModeSuggestion(
                    adjustmentType: .minorAdjustment,
                    workDays: workDays,
                    offDays: offDays,
                    totalDays: workDays + offDays,
                    targetReturnDay: targetReturnDay,
                    description: "Minor adjustment: Shift schedule by \(shift) days to achieve return on \(targetReturnDay.description)",
                    impactOnSalary: calculateSalaryImpact(workDays: workDays, offDays: offDays),
                    validationWarnings: validationWarnings,
                    futureSimulationWarnings: futureWarnings,
                    score: score,
                    isRecommended: isRecommended
                )
            }
        }
        
        return nil
    }
    
    private func attemptModerateAdjustment(
        schedule: WorkSchedule,
        interruptionEnd: Date,
        targetReturnDay: WorkSchedule.Weekday,
        workedDays: Int,
        earnedDays: Int,
        alerts: inout [OperationalAlert]
    ) -> SuggestModeSuggestion? {
        let calendar = Calendar.current
        let returnDate = calendar.date(byAdding: .day, value: 1, to: interruptionEnd) ?? interruptionEnd
        
        // Calculate days needed to reach target
        let currentWeekday = calendar.component(.weekday, from: returnDate)
        let currentDay = WorkSchedule.Weekday(rawValue: currentWeekday) ?? .monday
        let daysToTarget = calculateDaysToTarget(from: currentDay, to: targetReturnDay)
        
        // Try different cycle lengths
        let possibleCycles = [
            (workDays: 13, offDays: 7),
            (workDays: 12, offDays: 6),
            (workDays: 11, offDays: 5),
            (workDays: 10, offDays: 4),
            (workDays: 9, offDays: 4),
            (workDays: 8, offDays: 3),
            (workDays: 7, offDays: 3),
            (workDays: 6, offDays: 3)
        ]
        
        for cycle in possibleCycles {
            if cycle.workDays + cycle.offDays == daysToTarget {
                // Check operational constraints
                if cycle.workDays < 5 {
                    alerts.append(OperationalAlert(
                        type: .workdaysTooShort,
                        message: "The proposed cycle is too short (less than 5 workdays), which may make travel and scheduling impractical. Proceed anyway?",
                        requiresApproval: true
                    ))
                }
                
                if cycle.workDays > 14 {
                    alerts.append(OperationalAlert(
                        type: .workdaysTooLong,
                        message: "This proposal exceeds the standard 14-day work cycle. It usually requires supervisor approval. Continue anyway?",
                        requiresApproval: true
                    ))
                }
                
                // Validate and simulate
                let validationWarnings = validateSuggestion(
                    workDays: cycle.workDays,
                    offDays: cycle.offDays,
                    schedule: schedule,
                    interruptionEnd: interruptionEnd
                )
                
                let futureWarnings = simulateFutureAlignment(
                    workDays: cycle.workDays,
                    offDays: cycle.offDays,
                    schedule: schedule,
                    interruptionEnd: interruptionEnd,
                    targetReturnDay: targetReturnDay
                )
                
                // Check if this suggestion aligns with target return day
                let totalDays = cycle.workDays + cycle.offDays
                let cycleEndDate = calendar.date(byAdding: .day, value: totalDays, to: returnDate) ?? returnDate
                let nextStandardCycleStart = calendar.date(byAdding: .day, value: 1, to: cycleEndDate) ?? cycleEndDate
                let nextCycleStartWeekday = calendar.component(.weekday, from: nextStandardCycleStart)
                let nextCycleStartDay = WorkSchedule.Weekday(rawValue: nextCycleStartWeekday) ?? .monday
                let alignsWithTarget = (nextCycleStartDay == targetReturnDay)
                
                let score = calculateSuggestionScore(
                    workDays: cycle.workDays,
                    offDays: cycle.offDays,
                    validationWarnings: validationWarnings,
                    futureSimulationWarnings: futureWarnings,
                    adjustmentType: .moderateAdjustment,
                    alignsWithTargetReturnDay: alignsWithTarget
                )
                
                let isRecommended = validationWarnings.isEmpty && futureWarnings.isEmpty && alignsWithTarget
                
                return SuggestModeSuggestion(
                    adjustmentType: .moderateAdjustment,
                    workDays: cycle.workDays,
                    offDays: cycle.offDays,
                    totalDays: cycle.workDays + cycle.offDays,
                    targetReturnDay: targetReturnDay,
                    description: "Moderate adjustment: New cycle of \(cycle.workDays) work + \(cycle.offDays) off days to achieve return on \(targetReturnDay.description)",
                    impactOnSalary: calculateSalaryImpact(workDays: cycle.workDays, offDays: cycle.offDays),
                    validationWarnings: validationWarnings,
                    futureSimulationWarnings: futureWarnings,
                    score: score,
                    isRecommended: isRecommended
                )
            }
        }
        
        return nil
    }
    
    private func attemptCycleReconstruction(
        schedule: WorkSchedule,
        interruptionEnd: Date,
        targetReturnDay: WorkSchedule.Weekday,
        workedDays: Int,
        earnedDays: Int
    ) -> SuggestModeSuggestion {
        let calendar = Calendar.current
        let returnDate = calendar.date(byAdding: .day, value: 1, to: interruptionEnd) ?? interruptionEnd
        
        // Calculate days needed to reach target
        let currentWeekday = calendar.component(.weekday, from: returnDate)
        let currentDay = WorkSchedule.Weekday(rawValue: currentWeekday) ?? .monday
        let daysToTarget = calculateDaysToTarget(from: currentDay, to: targetReturnDay)
        
        // Create a complete new cycle
        let newWorkDays = max(6, min(14, daysToTarget - 7)) // Leave room for off days
        let newOffDays = max(3, min(7, daysToTarget - newWorkDays))
        
        // Validate and simulate
        let validationWarnings = validateSuggestion(
            workDays: newWorkDays,
            offDays: newOffDays,
            schedule: schedule,
            interruptionEnd: interruptionEnd
        )
        
        let futureWarnings = simulateFutureAlignment(
            workDays: newWorkDays,
            offDays: newOffDays,
            schedule: schedule,
            interruptionEnd: interruptionEnd,
            targetReturnDay: targetReturnDay
        )
        
        // Check if this suggestion aligns with target return day
        let totalDays = newWorkDays + newOffDays
        let cycleEndDate = calendar.date(byAdding: .day, value: totalDays, to: returnDate) ?? returnDate
        let nextStandardCycleStart = calendar.date(byAdding: .day, value: 1, to: cycleEndDate) ?? cycleEndDate
        let nextCycleStartWeekday = calendar.component(.weekday, from: nextStandardCycleStart)
        let nextCycleStartDay = WorkSchedule.Weekday(rawValue: nextCycleStartWeekday) ?? .monday
        let alignsWithTarget = (nextCycleStartDay == targetReturnDay)
        
        let score = calculateSuggestionScore(
            workDays: newWorkDays,
            offDays: newOffDays,
            validationWarnings: validationWarnings,
            futureSimulationWarnings: futureWarnings,
            adjustmentType: .cycleReconstruction,
            alignsWithTargetReturnDay: alignsWithTarget
        )
        
        let isRecommended = validationWarnings.isEmpty && futureWarnings.isEmpty && alignsWithTarget
        
        return SuggestModeSuggestion(
            adjustmentType: .cycleReconstruction,
            workDays: newWorkDays,
            offDays: newOffDays,
            totalDays: newWorkDays + newOffDays,
            targetReturnDay: targetReturnDay,
            description: "Cycle reconstruction: Complete rebuild with \(newWorkDays) work + \(newOffDays) off days to ensure return on \(targetReturnDay.description)",
            impactOnSalary: calculateSalaryImpact(workDays: newWorkDays, offDays: newOffDays),
            validationWarnings: validationWarnings,
            futureSimulationWarnings: futureWarnings,
            score: score,
            isRecommended: isRecommended
        )
    }
    
    private func calculateDaysToTarget(from currentDay: WorkSchedule.Weekday, to targetDay: WorkSchedule.Weekday) -> Int {
        let currentValue = currentDay.rawValue
        let targetValue = targetDay.rawValue
        
        if targetValue >= currentValue {
            return targetValue - currentValue
        } else {
            return (7 - currentValue) + targetValue
        }
    }
    
    private func calculateSalaryImpact(workDays: Int, offDays: Int) -> String {
        let standardWorkDays = 14
        let standardOffDays = 7
        
        let workDifference = workDays - standardWorkDays
        let offDifference = offDays - standardOffDays
        
        if workDifference == 0 && offDifference == 0 {
            return "No impact on salary"
        } else if workDifference > 0 {
            return "Potential overtime for \(workDifference) additional work days"
        } else if workDifference < 0 {
            return "Reduced salary for \(abs(workDifference)) fewer work days"
        } else {
            return "Schedule adjustment may affect salary calculation"
        }
    }
    
    // MARK: - Schedule Generation
    
    func generateSchedule(from startDate: Date, for months: Int = 12, hitchStartDate: Date? = nil) -> WorkSchedule {
        var schedule = WorkSchedule(startDate: startDate)
        let calendar = Calendar.current
        
        guard let endDate = calendar.date(byAdding: .month, value: months, to: startDate) else {
            return schedule
        }
        
        // Start with a clean slate
        schedule.days = []
        
        var currentDate = startDate
        var workDaysCount = 0
        var earnedOffDays = 0
        
        // Create a pattern of 14 work days followed by 7 off days
        let hitchCycle = 21 // 14 on, 7 off
        
        // Calculate initial dayInCycle based on hitchStartDate if provided
        var dayInCycle: Int
        if let hitchStart = hitchStartDate {
            // Normalize dates for accurate day calculation
            let normalizedHitchStart = normalizeToStartOfDay(hitchStart)
            let normalizedStartDate = normalizeToStartOfDay(startDate)
            let daysSinceHitchStart = calendar.dateComponents([.day], from: normalizedHitchStart, to: normalizedStartDate).day ?? 0
            dayInCycle = (daysSinceHitchStart % hitchCycle + hitchCycle) % hitchCycle // Ensure positive
        } else {
            dayInCycle = 0
        }
        
        while currentDate <= endDate {
            // First, determine day type based on 14/7 pattern
            var type = determineDayTypeInHitchPattern(dayInCycle)

            // Check for public holiday, but preserve the 14-day work cycle
            let isHoliday = holidayService.isPublicHoliday(currentDate)
            if isHoliday && dayInCycle >= 14 {
                // holiday during the 7-day break
                if let holidayType = holidayService.getHolidayType(currentDate) {
                    type = convertHolidayTypeToDayType(holidayType)
                }
            }

            // Ramadan indicator
            let isRamadanDay = holidayService.isInRamadan(currentDate)

            // Compute baked overtime and ADL hours
            let overtime = computeOvertime(for: type, dayInCycle: dayInCycle, isHoliday: isHoliday)
            let adl = computeAdl(for: type, dayInCycle: dayInCycle, isHoliday: isHoliday)

            // Build the schedule day with baked hours and cycle flag
            let day = WorkSchedule.ScheduleDay(
                id: UUID(),
                date: currentDate,
                type: type,
                isHoliday: isHoliday,
                isOverride: false,
                notes: nil,
                overtimeHours: overtime,
                adlHours: adl,
                isInHitch: dayInCycle < 14,
                hasIcon: isRamadanDay,
                iconName: isRamadanDay ? "moon.stars.fill" : nil
            )

            schedule.days.append(day)

            // Track work days and earned off days
            if type == .workday {
                workDaysCount += 1
                if workDaysCount % 2 == 0 {
                    earnedOffDays += 1
                }
            }

            // Move to next day
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            dayInCycle = (dayInCycle + 1) % hitchCycle
        }
        
        return schedule
    }
    
    private func determineDayTypeInHitchPattern(_ dayInCycle: Int) -> DayType {
        // Standard 14-7 pattern:
        // Days 0-13: Work days
        // Days 14-20: Off days
        if dayInCycle < 14 {
            return .workday
        } else {
            return .earnedOffDay
        }
    }
    
    // MARK: - Holiday Type Conversion
    
    private func convertHolidayTypeToDayType(_ holidayType: HolidayType) -> DayType {
        switch holidayType {
        case .eidHoliday:
            return .eidHoliday
        case .nationalDay:
            return .nationalDay
        case .foundingDay:
            return .foundingDay
        case .companyOff:
            return .companyOff
        }
    }
    
    // Public method for backward compatibility
    func isEidHoliday(_ date: Date) -> Bool {
        return holidayService.isEidHoliday(date)
    }
    

    
    // MARK: - Interruption Handling
    
    func handleInterruption(_ schedule: inout WorkSchedule, startDate: Date, endDate: Date, type: WorkSchedule.InterruptionType, preferredReturnDay: WorkSchedule.Weekday? = nil) {
        schedule.isInterrupted = true
        schedule.interruptionStart = startDate
        schedule.interruptionEnd = endDate
        schedule.interruptionType = type
        schedule.preferredReturnDay = preferredReturnDay
        
        // If schedule was manually adjusted before, warn and exit
        if schedule.manuallyAdjusted {
            // We would just mark days and not recalculate
            markInterruptionDays(&schedule, startDate: startDate, endDate: endDate, type: type)
            return
        }
        
        // Calculate worked days and earned off days before interruption
        let (workedDays, earnedDays) = calculateWorkedAndEarnedDaysBeforeInterruption(schedule, interruptionStart: startDate)
        
        // Store these counts for reference
        schedule.workedDaysBeforeInterruption = workedDays
        schedule.earnedOffDaysBeforeInterruption = earnedDays
        
        // Apply earned off days first to cover beginning of interruption
        applyEarnedOffDaysToInterruption(&schedule, startDate: startDate, endDate: endDate, earnedDays: earnedDays)
        
        // Check for training conflicts and plan reschedule if needed
        let trainingPeriod: DateInterval? = (type == .training) ? DateInterval(start: startDate, end: endDate) : nil
        let hasTrainingConflict = trainingPeriod != nil && checkTrainingOverlapsOffDays(schedule, startDate: startDate, endDate: endDate)
        
        // Use flexible rescheduling if we have preferred return day or training conflicts
        if preferredReturnDay != nil || hasTrainingConflict {
            let returnDate = Calendar.current.date(byAdding: .day, value: 1, to: endDate) ?? endDate
            
            // Create flexible reschedule plan
            let flexiblePlan = createFlexibleReschedulePlan(
                returnDate: returnDate,
                targetWorkday: preferredReturnDay ?? .monday,
                trainingPeriod: trainingPeriod
            )
            
            if flexiblePlan.isValid {
                // Validate plan before applying
                if let validationError = validateReschedulePlan(flexiblePlan) {
                    // Log warning - in production, this should be shown to user
                    print("⚠️ Warning: \(validationError)")
                }
                // Apply flexible reschedule plan
                applyFlexibleReschedulePlan(flexiblePlan, to: &schedule, startingFrom: returnDate)
            } else {
                // Fallback to legacy rescheduling
                let legacyPlan = planReschedule(
                    interruptionEnd: endDate,
                    trainingPeriod: trainingPeriod,
                    targetReturnDay: preferredReturnDay,
                    workDeficit: max(0, 14 - workedDays)
                )
                
                if legacyPlan.isValid {
                    // Validate plan before applying
                    if let validationError = validateReschedulePlan(legacyPlan) {
                        // Log warning - in production, this should be shown to user
                        print("⚠️ Warning: \(validationError)")
                    }
                    applyReschedulePlan(legacyPlan, to: &schedule)
                } else {
                    // Final fallback to original logic
                    applySmartReschedule(&schedule, workedDays: workedDays, earnedDays: earnedDays, preferredReturnDay: preferredReturnDay)
                }
            }
        } else {
            // Use original logic for simple cases
            applySmartReschedule(&schedule, workedDays: workedDays, earnedDays: earnedDays, preferredReturnDay: preferredReturnDay)
        }
    }
    
    private func applyEarnedOffDaysToInterruption(_ schedule: inout WorkSchedule, startDate: Date, endDate: Date, earnedDays: Int) {
        let calendar = Calendar.current
        let normalizedStart = normalizeToStartOfDay(startDate)
        let normalizedEnd = normalizeToStartOfDay(endDate)
        
        // Get the hitch start date to determine original day types
        let hitchStartDate = schedule.hitchStartDate ?? schedule.startDate
        let normalizedHitchStart = normalizeToStartOfDay(hitchStartDate)
        
        // PART D: Remove force unwrap crash risk - use safe guard instead
        guard let interruptionTypeRaw = schedule.interruptionType else {
            print("⚠️ interruptionType nil in applyEarnedOffDaysToInterruption; defaulting to vacation")
            let interruptionType = convertInterruptionTypeToDayType(.vacation)
            // Continue with default type - mark all days in interruption period
            for i in 0..<schedule.days.count {
                let day = schedule.days[i]
                let normalizedDayDate = normalizeToStartOfDay(day.date)
                
                if normalizedDayDate >= normalizedStart && normalizedDayDate <= normalizedEnd {
                    schedule.days[i].type = interruptionType
                    schedule.days[i].notes = "Interruption day"
                    schedule.days[i].isOverride = false
                }
                
                if normalizedDayDate > normalizedEnd {
                    break
                }
            }
            return
        }
        
        // Step 1: Mark ALL days in interruption period as interruption type first
        // This ensures the first day (e.g., Dec 1) is always marked
        let interruptionType = convertInterruptionTypeToDayType(interruptionTypeRaw)
        
        for i in 0..<schedule.days.count {
            let day = schedule.days[i]
            let normalizedDayDate = normalizeToStartOfDay(day.date)
            
            if normalizedDayDate >= normalizedStart && normalizedDayDate <= normalizedEnd {
                // Mark all days in interruption period as interruption type
                schedule.days[i].type = interruptionType
                schedule.days[i].notes = "Interruption day"
                schedule.days[i].isOverride = false
            }
            
            if normalizedDayDate > normalizedEnd {
                break
            }
        }
        
        // Step 2: Apply earned off days ONLY to days that were originally workdays
        // Earned off days should only replace workdays, not off days
        var remainingEarnedDays = earnedDays
        
        for i in 0..<schedule.days.count {
            let day = schedule.days[i]
            let normalizedDayDate = normalizeToStartOfDay(day.date)
            
            if normalizedDayDate >= normalizedStart && normalizedDayDate <= normalizedEnd {
                // Determine if this day was originally a workday using the hitch pattern
                let daysSinceHitchStart = calendar.dateComponents([.day], from: normalizedHitchStart, to: normalizedDayDate).day ?? 0
                let dayInCycle = (daysSinceHitchStart % 21 + 21) % 21 // Ensure positive
                
                // Only apply earned off days to days that were originally workdays (days 0-13 in cycle)
                if dayInCycle < 14 && remainingEarnedDays > 0 {
                    schedule.days[i].type = .earnedOffDay
                    schedule.days[i].notes = "Earned off day due to work before interruption"
                    schedule.days[i].isOverride = false
                    remainingEarnedDays -= 1
                }
                // Days that were originally off days (days 14-20) remain as interruption type
            }
            
            if normalizedDayDate > normalizedEnd {
                break
            }
        }
    }
    
    private func handleTrainingDays(_ schedule: inout WorkSchedule, startDate: Date, endDate: Date) {
        // For training, we need to ensure training days only fall on would-be work days
        let calendar = Calendar.current
        for i in 0..<schedule.days.count {
            let day = schedule.days[i]
            if isDateInRange(day.date, start: startDate, end: endDate) {
                let dayPosition = calendar.dateComponents([.day], from: schedule.startDate, to: day.date).day! % 21
                // Check if this would normally be an off day (days 14-20 in cycle)
                if dayPosition >= 14 {
                    // This would be an off day, but training is scheduled
                    // Mark it for rescheduling
                    schedule.days[i].type = .autoRescheduled
                    schedule.days[i].notes = "Training rescheduled - must occur on workday"
                    // In a real implementation, you'd need to find the next available
                    // workday and reschedule the training there
                }
            }
        }
    }
    
    func markInterruptionDays(_ schedule: inout WorkSchedule, startDate: Date, endDate: Date, type: WorkSchedule.InterruptionType) {
        let dayType = convertInterruptionTypeToDayType(type)
        
        for i in 0..<schedule.days.count {
            let day = schedule.days[i]
            
            // Use normalized date comparison for consistency
            if isDateInRange(day.date, start: startDate, end: endDate) {
                schedule.days[i].type = dayType
                schedule.days[i].isOverride = false
                schedule.days[i].notes = "Part of \(type.rawValue) interruption"
            }
            
            // Early exit optimization
            let normalizedDayDate = normalizeToStartOfDay(day.date)
            let normalizedEnd = normalizeToStartOfDay(endDate)
            if normalizedDayDate > normalizedEnd {
                break
            }
        }
    }
    
    // MARK: - Binding Alternative Application
    
    /// Applies interruption with a binding executable alternative block
    /// This is the dedicated method for applying alternatives selected via "Accept Exception"
    /// The alternative becomes a concrete, binding part of the schedule.
    /// 
    /// Steps:
    /// 1. Apply interruption days correctly (earned off first, then vacation)
    /// 2. Apply the chosen alternative as a real post-interruption block
    ///    - Starting the day after interruption ends
    ///    - Mark workDays consecutive .work
    ///    - Mark offDays consecutive .off
    /// 3. After that block ends, resume the standard 14W / 7O baseline forward
    func applyInterruptionThenAlternativeBlock(
        _ schedule: inout WorkSchedule,
        interruptionType: WorkSchedule.InterruptionType,
        interruptionStart: Date,
        interruptionEnd: Date,
        alternativeWorkDays: Int,
        alternativeOffDays: Int
    ) {
        let calendar = Calendar.current
        let normalizedStart = normalizeToStartOfDay(interruptionStart)
        let normalizedEnd = normalizeToStartOfDay(interruptionEnd)
        
        // Set interruption metadata
        schedule.isInterrupted = true
        schedule.interruptionStart = interruptionStart
        schedule.interruptionEnd = interruptionEnd
        schedule.interruptionType = interruptionType
        
        // PART 1: Apply interruption days correctly (Earned Off first, then Vacation)
        let (workedDays, earnedDays) = calculateWorkedAndEarnedDaysBeforeInterruption(schedule, interruptionStart: interruptionStart)
        schedule.workedDaysBeforeInterruption = workedDays
        schedule.earnedOffDaysBeforeInterruption = earnedDays
        
        // Calculate total interruption days
        let totalInterruptionDays = (calendar.dateComponents([.day], from: interruptionStart, to: interruptionEnd).day ?? 0) + 1
        let earnedUsed = min(earnedDays, totalInterruptionDays)
        
        // Get hitch start to determine original day types
        let hitchStartDate = schedule.hitchStartDate ?? schedule.startDate
        let normalizedHitchStart = normalizeToStartOfDay(hitchStartDate)
        let interruptionDayType = convertInterruptionTypeToDayType(interruptionType)
        
        // Step 1: Mark all interruption days as interruption type first
        for i in 0..<schedule.days.count {
            let day = schedule.days[i]
            let normalizedDayDate = normalizeToStartOfDay(day.date)
            
            if normalizedDayDate >= normalizedStart && normalizedDayDate <= normalizedEnd {
                schedule.days[i].type = interruptionDayType
                schedule.days[i].notes = "Interruption day"
                schedule.days[i].isOverride = false
            }
            
            if normalizedDayDate > normalizedEnd {
                break
            }
        }
        
        // Step 2: Apply earned off days first (only to originally workdays)
        var remainingEarnedDays = earnedUsed
        for i in 0..<schedule.days.count {
            let day = schedule.days[i]
            let normalizedDayDate = normalizeToStartOfDay(day.date)
            
            if normalizedDayDate >= normalizedStart && normalizedDayDate <= normalizedEnd {
                // Determine if this day was originally a workday using the hitch pattern
                let daysSinceHitchStart = calendar.dateComponents([.day], from: normalizedHitchStart, to: normalizedDayDate).day ?? 0
                let dayInCycle = (daysSinceHitchStart % 21 + 21) % 21 // Ensure positive
                
                // Only apply earned off to originally workdays (days 0-13 in cycle)
                if dayInCycle < 14 && remainingEarnedDays > 0 {
                    schedule.days[i].type = .earnedOffDay
                    schedule.days[i].notes = "Earned off day due to work before interruption"
                    schedule.days[i].isOverride = false
                    remainingEarnedDays -= 1
                }
                // Days that were originally off days (days 14-20) remain as interruption type
            }
            
            if normalizedDayDate > normalizedEnd {
                break
            }
        }
        
        // PART 2: Apply the selected alternative as an executable block
        // Starting the day after interruption ends
        let resumeDate = calendar.date(byAdding: .day, value: 1, to: interruptionEnd) ?? interruptionEnd
        guard let resumeIndex = schedule.days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: resumeDate) }) else {
            print("⚠️ Could not find resume date in schedule")
            return
        }
        
        var currentIndex = resumeIndex
        
        // Mark alternativeWorkDays consecutive days as .work
        for _ in 0..<alternativeWorkDays {
            if currentIndex < schedule.days.count {
                schedule.days[currentIndex].type = .workday
                schedule.days[currentIndex].notes = "Binding Alternative: \(alternativeWorkDays)W/\(alternativeOffDays)O cycle"
                schedule.days[currentIndex].isOverride = false
                schedule.days[currentIndex].isInHitch = true
                currentIndex += 1
            }
        }
        
        // Mark alternativeOffDays consecutive days as .off
        for _ in 0..<alternativeOffDays {
            if currentIndex < schedule.days.count {
                schedule.days[currentIndex].type = .earnedOffDay
                schedule.days[currentIndex].notes = "Binding Alternative: \(alternativeWorkDays)W/\(alternativeOffDays)O cycle"
                schedule.days[currentIndex].isOverride = false
                schedule.days[currentIndex].isInHitch = false
                currentIndex += 1
            }
        }
        
        // PART 3: Resume baseline 14W / 7O from the end of the alternative block
        let baselineAnchor = currentIndex
        if baselineAnchor < schedule.days.count {
            applyStandard14_7Pattern(&schedule, startingFrom: baselineAnchor)
        }
        
        // Log instrumentation for verification
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        
        print("""
        ✅ Binding Alternative Applied:
           Interruption: \(dateFormatter.string(from: interruptionStart)) to \(dateFormatter.string(from: interruptionEnd))
           Earned Off Used: \(earnedUsed) of \(earnedDays) available
           Vacation Used: \(max(0, totalInterruptionDays - earnedUsed))
           Alternative Block: \(alternativeWorkDays)W/\(alternativeOffDays)O starting \(dateFormatter.string(from: resumeDate))
           Baseline 14W/7O resumes from index \(baselineAnchor)
        """)
    }
    
    // MARK: - Suggest Mode Application
    
    /// Applies a Suggest Mode suggestion to the schedule
    /// This method:
    /// 1. Marks interruption days using earned off first, then vacation
    /// 2. Applies the chosen suggestion cycle immediately after interruption
    /// 3. Resumes standard 14W/7O after the suggestion segment
    func applySuggestModeSuggestion(
        _ schedule: inout WorkSchedule,
        suggestion: SuggestModeSuggestion,
        interruptionStart: Date,
        interruptionEnd: Date,
        interruptionType: WorkSchedule.InterruptionType
    ) {
        // #region agent log
        let logEntry = "{\"location\":\"ScheduleEngine.swift:1393\",\"message\":\"applySuggestModeSuggestion ENTRY\",\"data\":{\"suggestionW\":\(suggestion.workDays),\"suggestionO\":\(suggestion.offDays),\"score\":\(suggestion.score)},\"timestamp\":\(Int(Date().timeIntervalSince1970*1000)),\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"H3\"}\n"
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
        print("🔍 DEBUG: ScheduleEngine.applySuggestModeSuggestion called with: \(suggestion.workDays)W/\(suggestion.offDays)O")
        // #endregion
        let calendar = Calendar.current
        let normalizedStart = normalizeToStartOfDay(interruptionStart)
        let normalizedEnd = normalizeToStartOfDay(interruptionEnd)
        
        // Set interruption metadata
        schedule.isInterrupted = true
        schedule.interruptionStart = interruptionStart
        schedule.interruptionEnd = interruptionEnd
        schedule.interruptionType = interruptionType
        
        // C1: Mark interruption days correctly using earned off first
        let (workedDays, earnedDays) = calculateWorkedAndEarnedDaysBeforeInterruption(schedule, interruptionStart: interruptionStart)
        schedule.workedDaysBeforeInterruption = workedDays
        schedule.earnedOffDaysBeforeInterruption = earnedDays
        
        // Get hitch start to determine original day types
        let hitchStartDate = schedule.hitchStartDate ?? schedule.startDate
        let normalizedHitchStart = normalizeToStartOfDay(hitchStartDate)
        let interruptionDayType = convertInterruptionTypeToDayType(interruptionType)
        
        // Step 1: Mark all interruption days as interruption type first
        for i in 0..<schedule.days.count {
            let day = schedule.days[i]
            let normalizedDayDate = normalizeToStartOfDay(day.date)
            
            if normalizedDayDate >= normalizedStart && normalizedDayDate <= normalizedEnd {
                schedule.days[i].type = interruptionDayType
                schedule.days[i].notes = "Interruption day"
                schedule.days[i].isOverride = false
            }
            
            if normalizedDayDate > normalizedEnd {
                break
            }
        }
        
        // Step 2: Apply earned off days first (only to originally workdays)
        var remainingEarnedDays = earnedDays
        for i in 0..<schedule.days.count {
            let day = schedule.days[i]
            let normalizedDayDate = normalizeToStartOfDay(day.date)
            
            if normalizedDayDate >= normalizedStart && normalizedDayDate <= normalizedEnd {
                // Determine if this day was originally a workday using the hitch pattern
                let daysSinceHitchStart = calendar.dateComponents([.day], from: normalizedHitchStart, to: normalizedDayDate).day ?? 0
                let dayInCycle = (daysSinceHitchStart % 21 + 21) % 21 // Ensure positive
                
                // Only apply earned off to originally workdays (days 0-13 in cycle)
                if dayInCycle < 14 && remainingEarnedDays > 0 {
                    schedule.days[i].type = .earnedOffDay
                    schedule.days[i].notes = "Earned off day due to work before interruption"
                    schedule.days[i].isOverride = false
                    remainingEarnedDays -= 1
                }
                // Days that were originally off days (days 14-20) remain as interruption type
            }
            
            if normalizedDayDate > normalizedEnd {
                break
            }
        }
        
        // C2: Apply the chosen suggestion cycle immediately after interruption
        let resumeDate = calendar.date(byAdding: .day, value: 1, to: interruptionEnd) ?? interruptionEnd
        guard let resumeIndex = schedule.days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: resumeDate) }) else {
            print("⚠️ Could not find resume date in schedule")
            return
        }
        
        var currentIndex = resumeIndex
        
        // #region agent log
        let logWork = "{\"location\":\"ScheduleEngine.swift:1511\",\"message\":\"About to apply work days\",\"data\":{\"suggestionW\":\(suggestion.workDays),\"suggestionO\":\(suggestion.offDays),\"resumeIndex\":\(resumeIndex)},\"timestamp\":\(Int(Date().timeIntervalSince1970*1000)),\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"H3\"}\n"
        if let data = logWork.data(using: .utf8) {
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
        print("🔍 DEBUG: ScheduleEngine applying: \(suggestion.workDays)W/\(suggestion.offDays)O starting at index \(resumeIndex)")
        // #endregion
        // Apply work days from suggestion
        for _ in 0..<suggestion.workDays {
            if currentIndex < schedule.days.count {
                schedule.days[currentIndex].type = .workday
                schedule.days[currentIndex].notes = "Suggest Mode: \(suggestion.workDays)W/\(suggestion.offDays)O cycle"
                schedule.days[currentIndex].isOverride = false
                schedule.days[currentIndex].isInHitch = true
                currentIndex += 1
            }
        }
        
        // Apply off days from suggestion
        for _ in 0..<suggestion.offDays {
            if currentIndex < schedule.days.count {
                schedule.days[currentIndex].type = .earnedOffDay
                schedule.days[currentIndex].notes = "Suggest Mode: \(suggestion.workDays)W/\(suggestion.offDays)O cycle"
                schedule.days[currentIndex].isOverride = false
                schedule.days[currentIndex].isInHitch = false
                currentIndex += 1
            }
        }
        
        // PART 2: Compute next standard hitch start date using the same helper as analyzer
        let nextStandardStart = nextStandardHitchStartDate(
            interruptionEnd: interruptionEnd,
            suggestionWorkDays: suggestion.workDays,
            suggestionOffDays: suggestion.offDays,
            calendar: calendar
        )
        
        // PART 2: Find the index that corresponds to nextStandardStart date
        let nextStandardWeekday = calendar.component(.weekday, from: nextStandardStart)
        let nextStandardDay = WorkSchedule.Weekday(rawValue: nextStandardWeekday) ?? .monday
        
        guard let nextStandardIndex = schedule.days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: nextStandardStart) }) else {
            print("⚠️ Could not find next standard start date in schedule, using currentIndex")
            // Fallback to currentIndex if date not found
            if currentIndex < schedule.days.count {
                applyStandard14_7Pattern(&schedule, startingFrom: currentIndex)
            }
            // PART 2: Debug log even in fallback case
            print("APPLY \(suggestion.workDays)W/\(suggestion.offDays)O -> next14/7Start=\(nextStandardStart) weekday=\(nextStandardDay.description) (FALLBACK to index \(currentIndex))")
            return
        }
        
        // PART 2: Debug log
        print("APPLY \(suggestion.workDays)W/\(suggestion.offDays)O -> next14/7Start=\(nextStandardStart) weekday=\(nextStandardDay.description)")
        
        // PART 2: Resume standard 14W/7O from the exact nextStandardStart date (not currentIndex)
        if nextStandardIndex < schedule.days.count {
            applyStandard14_7Pattern(&schedule, startingFrom: nextStandardIndex)
        }
        
        // PART E: Add definitive debug log to prove binding works
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        
        let totalInterruptionDays = (calendar.dateComponents([.day], from: interruptionStart, to: interruptionEnd).day ?? 0) + 1
        let earnedOffUsed = earnedDays - remainingEarnedDays
        let vacationUsed = max(0, totalInterruptionDays - earnedOffUsed)
        
        print("""
        ✅ ScheduleEngine.applySuggestModeSuggestion VERIFIED:
           Selected Pattern: \(suggestion.workDays)W/\(suggestion.offDays)O
           Applied Work Days: \(suggestion.workDays) (starting index \(resumeIndex))
           Applied Off Days: \(suggestion.offDays)
           Interruption: \(dateFormatter.string(from: interruptionStart)) to \(dateFormatter.string(from: interruptionEnd))
           Earned Off Used: \(earnedOffUsed) of \(earnedDays) available
           Vacation Used: \(vacationUsed)
           Next Standard Start: \(dateFormatter.string(from: nextStandardStart)) (weekday: \(nextStandardDay.description))
           Baseline 14W/7O resumes from index \(nextStandardIndex)
        """)
        
        // Verify the applied segment matches the suggestion
        var appliedWorkDays = 0
        var appliedOffDays = 0
        for i in resumeIndex..<min(resumeIndex + suggestion.workDays + suggestion.offDays, schedule.days.count) {
            if schedule.days[i].type == .workday {
                appliedWorkDays += 1
            } else if schedule.days[i].type == .earnedOffDay {
                appliedOffDays += 1
            }
        }
        
        print("""
        ✅ Suggest Mode Applied:
           Selected: \(suggestion.workDays)W/\(suggestion.offDays)O
           Interruption: \(dateFormatter.string(from: interruptionStart)) to \(dateFormatter.string(from: interruptionEnd))
           Earned Off Used: \(earnedOffUsed)
           Vacation Used: \(vacationUsed)
           Applied Segment Start: \(dateFormatter.string(from: resumeDate))
           Applied Segment: \(suggestion.workDays) work, \(suggestion.offDays) off
           Verified Applied: \(appliedWorkDays) work, \(appliedOffDays) off ✅
           Next Standard Start: \(dateFormatter.string(from: nextStandardStart)) (weekday: \(nextStandardDay.description))
           Standard 14W/7O resumes from index \(nextStandardIndex)
        """)
        
        // Verify the pattern matches
        if appliedWorkDays != suggestion.workDays || appliedOffDays != suggestion.offDays {
            print("⚠️ WARNING: Applied pattern (\(appliedWorkDays)W/\(appliedOffDays)O) does not match selected (\(suggestion.workDays)W/\(suggestion.offDays)O)")
        }
    }
    
    private func convertInterruptionTypeToDayType(_ type: WorkSchedule.InterruptionType) -> DayType {
        switch type {
        case .shortLeave:
            return .vacation // Use vacation type for short leave
        case .vacation:
            return .vacation
        case .training:
            return .training
        case .companyOff:
            return .companyOff
        }
    }
    
    func calculateWorkedAndEarnedDaysBeforeInterruption(_ schedule: WorkSchedule, interruptionStart: Date) -> (worked: Int, earned: Int) {
        var workedDays = 0
        let calendar = Calendar.current
        
        // FIXED: Use hitchStartDate if available, otherwise fall back to startDate
        let hitchStartDate = schedule.hitchStartDate ?? schedule.startDate
        let normalizedHitchStart = normalizeToStartOfDay(hitchStartDate)
        let normalizedInterruptionStart = normalizeToStartOfDay(interruptionStart)
        
        // Find the most recent hitch start date before the interruption
        var currentHitchStartDate = normalizedHitchStart
        let daysSinceOriginalStart = calendar.dateComponents([.day], from: normalizedHitchStart, to: normalizedInterruptionStart).day ?? 0
        let completedCycles = daysSinceOriginalStart / 21
        
        if completedCycles > 0 {
            // Move to the start of the current hitch cycle
            currentHitchStartDate = calendar.date(byAdding: .day, value: completedCycles * 21, to: normalizedHitchStart) ?? normalizedHitchStart
        }
        
        // Loop through schedule days from the current hitch start until interruption
        for day in schedule.days {
            let normalizedDayDate = normalizeToStartOfDay(day.date)
            
            // Only process days within the current hitch and before interruption (exclusive)
            if normalizedDayDate >= currentHitchStartDate && normalizedDayDate < normalizedInterruptionStart {
                // Only count actual workdays, not all days
                if day.type == .workday {
                    workedDays += 1
                }
            }
            
            // Early exit if we've passed the interruption start
            if normalizedDayDate >= normalizedInterruptionStart {
                break
            }
        }
        
        // FIXED: Use ceiling division for correct earned days calculation
        let earnedOffDays = Int(ceil(Double(workedDays) / 2.0))
        
        return (workedDays, earnedOffDays)
    }
    
    // MARK: - Flexible Reschedule Planning Engine
    
    /// Creates flexible rescheduling cycles that adapt to reach target workday
    /// - Parameters:
    ///   - returnDate: Date when employee returns to work after interruption
    ///   - targetWorkday: Target workday (Sunday, Monday, Tuesday, etc.)
    ///   - trainingPeriod: Optional training period that needs accommodation
    /// - Returns: Flexible reschedule plan with adaptive cycles
    func createFlexibleReschedulePlan(
        returnDate: Date,
        targetWorkday: WorkSchedule.Weekday,
        trainingPeriod: DateInterval? = nil
    ) -> FlexibleReschedulePlan {
        // First try deterministic approach for specific patterns
        if let deterministicPlan = createDeterministicReschedulePlan(
            returnDate: returnDate,
            targetWorkday: targetWorkday,
            trainingPeriod: trainingPeriod
        ) {
            return deterministicPlan
        }
        
        // Fallback to original flexible approach
        let calendar = Calendar.current
        var currentDate = returnDate
        var cycles: [FlexibleCycle] = []
        var totalWorkDays = 0
        var totalOffDays = 0
        
        // Continue creating cycles until we reach target workday
        while true {
            let cycle = calculateOptimalFlexibleCycle(
                startDate: currentDate,
                targetWorkday: targetWorkday,
                trainingPeriod: trainingPeriod,
                remainingCycles: cycles.count
            )
            
            cycles.append(cycle)
            totalWorkDays += cycle.workDays
            totalOffDays += cycle.offDays
            
            // Move to next cycle start
            currentDate = calendar.date(byAdding: .day, value: cycle.totalDays, to: currentDate) ?? currentDate
            
            // Check if we've reached target workday
            if calendar.component(.weekday, from: currentDate) == targetWorkday.rawValue {
                break
            }
            
            // Safety check: prevent infinite loops (but allow more cycles than rigid system)
            if cycles.count > 10 {
                break
            }
        }
        
        return FlexibleReschedulePlan(
            cycles: cycles,
            finalReturnDate: currentDate,
            totalWorkDays: totalWorkDays,
            totalOffDays: totalOffDays,
            trainingAccommodated: trainingPeriod != nil
        )
    }
    
    /// Creates a deterministic reschedule plan that tries specific patterns
    private func createDeterministicReschedulePlan(
        returnDate: Date,
        targetWorkday: WorkSchedule.Weekday,
        trainingPeriod: DateInterval? = nil
    ) -> FlexibleReschedulePlan? {
        let calendar = Calendar.current
        
        // Try different cycle combinations to find one that lands on target workday
        let possiblePatterns = [
            [(workDays: 13, offDays: 7), (workDays: 8, offDays: 4)], // User's desired pattern
            [(workDays: 12, offDays: 6), (workDays: 9, offDays: 5)],
            [(workDays: 14, offDays: 7), (workDays: 7, offDays: 3)],
            [(workDays: 11, offDays: 5), (workDays: 10, offDays: 6)],
            [(workDays: 13, offDays: 6), (workDays: 8, offDays: 5)]
        ]
        
        for pattern in possiblePatterns {
            var testDate = returnDate
            var cycles: [FlexibleCycle] = []
            var totalWorkDays = 0
            var totalOffDays = 0
            
            // Apply the pattern
            for (workDays, offDays) in pattern {
                cycles.append(FlexibleCycle(workDays: workDays, offDays: offDays))
                totalWorkDays += workDays
                totalOffDays += offDays
                
                // Move to next cycle start
                testDate = calendar.date(byAdding: .day, value: workDays + offDays, to: testDate) ?? testDate
            }
            
            // Check if this pattern lands on target workday
            if calendar.component(.weekday, from: testDate) == targetWorkday.rawValue {
                return FlexibleReschedulePlan(
                    cycles: cycles,
                    finalReturnDate: testDate,
                    totalWorkDays: totalWorkDays,
                    totalOffDays: totalOffDays,
                    trainingAccommodated: trainingPeriod != nil
                )
            }
        }
        
        return nil
    }
    
    /// Calculates optimal cycle that accommodates training and reaches target workday
    private func calculateOptimalFlexibleCycle(
        startDate: Date,
        targetWorkday: WorkSchedule.Weekday,
        trainingPeriod: DateInterval?,
        remainingCycles: Int
    ) -> FlexibleCycle {
        let calendar = Calendar.current
        
        if let training = trainingPeriod {
            // Check if training falls in this potential cycle
            let potentialWorkDays = calculateFlexibleWorkDays(for: startDate, targetWorkday: targetWorkday)
            let potentialOffDays = calculateFlexibleOffDays(for: potentialWorkDays)
            let cycleEnd = calendar.date(byAdding: .day, value: potentialWorkDays + potentialOffDays, to: startDate) ?? startDate
            
            if training.start >= startDate && training.end <= cycleEnd {
                // Training falls in this cycle - adjust to accommodate
                if training.start >= startDate && training.end <= calendar.date(byAdding: .day, value: potentialWorkDays, to: startDate) ?? startDate {
                    // Training fits in work period - perfect!
                    return FlexibleCycle(workDays: potentialWorkDays, offDays: potentialOffDays)
                } else {
                    // Training would fall in off period - extend work period
                    let extendedWorkDays = calculateExtendedWorkDays(toInclude: training, from: startDate)
                    let adjustedOffDays = calculateAdjustedOffDays(for: extendedWorkDays)
                    return FlexibleCycle(workDays: extendedWorkDays, offDays: adjustedOffDays)
                }
            }
        }
        
        // No training conflict - use flexible cycle
        let workDays = calculateFlexibleWorkDays(for: startDate, targetWorkday: targetWorkday)
        let offDays = calculateFlexibleOffDays(for: workDays)
        return FlexibleCycle(workDays: workDays, offDays: offDays)
    }
    
    /// Calculates flexible work days based on needs (no rigid caps)
    private func calculateFlexibleWorkDays(for startDate: Date, targetWorkday: WorkSchedule.Weekday) -> Int {
        // Calculate days needed to reach target workday
        let daysToTarget = calculateDaysToTargetWorkday(from: startDate, target: targetWorkday)
        
        // Flexible work days: 6-14 days based on needs
        if daysToTarget <= 14 {
            return min(8, daysToTarget - 3) // Leave room for off days
        } else if daysToTarget <= 28 {
            return min(12, daysToTarget - 6) // Longer work period for longer cycles
        } else {
            return min(14, daysToTarget - 8) // Maximum flexibility for long cycles
        }
    }
    
    /// Calculates flexible off days (no forced 2:1 ratio per cycle)
    private func calculateFlexibleOffDays(for workDays: Int) -> Int {
        // Flexible off days: 2-7 days based on work days
        if workDays <= 6 {
            return 3
        } else if workDays <= 10 {
            return 4
        } else if workDays <= 12 {
            return 5
        } else {
            return 7
        }
    }
    
    /// Calculates extended work days to include training
    private func calculateExtendedWorkDays(toInclude training: DateInterval, from startDate: Date) -> Int {
        let calendar = Calendar.current
        let trainingStart = training.start
        let trainingEnd = training.end
        
        // Work period should start before or on training start
        let workStart = min(startDate, trainingStart)
        
        // Work period should end after or on training end
        let workEnd = max(calendar.date(byAdding: .day, value: 7, to: startDate) ?? startDate, trainingEnd) // At least 7 days
        
        return calendar.dateComponents([.day], from: workStart, to: workEnd).day ?? 7
    }
    
    /// Calculates adjusted off days for extended work periods
    private func calculateAdjustedOffDays(for workDays: Int) -> Int {
        // Adjusted off days: maintain overall balance but allow flexibility
        if workDays <= 8 {
            return 4
        } else if workDays <= 12 {
            return 5
        } else {
            return 7
        }
    }
    
    /// Calculates days needed to reach target workday
    private func calculateDaysToTargetWorkday(from startDate: Date, target: WorkSchedule.Weekday) -> Int {
        let calendar = Calendar.current
        var currentDate = startDate
        var days = 0
        
        while calendar.component(.weekday, from: currentDate) != target.rawValue {
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            days += 1
            
            // Safety check
            if days > 50 {
                break
            }
        }
        
        return days
    }
    
    // MARK: - Legacy Reschedule Planning (Preserved for backward compatibility)
    
    func planReschedule(
        interruptionEnd: Date,
        trainingPeriod: DateInterval?,
        targetReturnDay: WorkSchedule.Weekday?,
        workDeficit: Int
    ) -> ReschedulePlan {
        let calendar = Calendar.current
        let resumeDate = calendar.date(byAdding: .day, value: 1, to: interruptionEnd) ?? interruptionEnd
        
        var workPeriods: [(start: Date, end: Date, days: Int)] = []
        var offPeriods: [(start: Date, end: Date, days: Int)] = []
        var currentDate = resumeDate
        var totalWorkDays = 0
        var totalOffDays = 0
        
        // Calculate minimum work needed
        let minWorkDays = max(workDeficit, 6) // At least 6 days per micro-cycle
        
        // Generate micro-cycles until we reach target return day
        while true {
            // Work period
            let workStart = currentDate
            let workDays = min(minWorkDays, 8) // Flexible: 6-8 work days
            let workEnd = calendar.date(byAdding: .day, value: workDays - 1, to: workStart) ?? workStart
            
            workPeriods.append((start: workStart, end: workEnd, days: workDays))
            totalWorkDays += workDays
            
            // Check if training fits in this work period
            if let training = trainingPeriod {
                if training.start >= workStart && training.end <= workEnd {
                    // Training fits perfectly in this work period
                    break
                }
            }
            
            // Off period
            let offStart = calendar.date(byAdding: .day, value: 1, to: workEnd) ?? workEnd
            let offDays = Int(ceil(Double(workDays) / 2.0)) // Maintain 2:1 ratio
            let offEnd = calendar.date(byAdding: .day, value: offDays - 1, to: offStart) ?? offStart
            
            offPeriods.append((start: offStart, end: offEnd, days: offDays))
            totalOffDays += offDays
            
            // Check if we've reached target return day
            if let targetDay = targetReturnDay {
                let nextWorkStart = calendar.date(byAdding: .day, value: 1, to: offEnd) ?? offEnd
                if calendar.component(.weekday, from: nextWorkStart) == targetDay.rawValue {
                    break
                }
            }
            
            // Move to next cycle
            currentDate = calendar.date(byAdding: .day, value: 1, to: offEnd) ?? offEnd
            
            // Safety check: prevent infinite loops
            if workPeriods.count > 4 {
                break
            }
        }
        
        let finalReturnDate = offPeriods.last?.end ?? resumeDate
        let earnedDaysGenerated = Int(ceil(Double(totalWorkDays) / 2.0))
        
        return ReschedulePlan(
            workPeriods: workPeriods,
            offPeriods: offPeriods,
            trainingPlacement: trainingPeriod,
            finalReturnDate: finalReturnDate,
            totalWorkDays: totalWorkDays,
            totalOffDays: totalOffDays,
            earnedDaysGenerated: earnedDaysGenerated
        )
    }
    
    func applyReschedulePlan(_ plan: ReschedulePlan, to schedule: inout WorkSchedule) {
        // Validate plan before applying
        if let validationError = validateReschedulePlan(plan) {
            // Log warning - in production, this should be shown to user
            print("⚠️ Warning: \(validationError)")
        }
        
        let calendar = Calendar.current
        
        // Apply work periods
        for workPeriod in plan.workPeriods {
            let startDate = workPeriod.start
            let endDate = workPeriod.end
            
            for i in 0..<schedule.days.count {
                let day = schedule.days[i]
                if isDateInRange(day.date, start: startDate, end: endDate) {
                    schedule.days[i].type = .workday
                    schedule.days[i].notes = "Rescheduled workday (micro-cycle)"
                    schedule.days[i].isOverride = false
                    schedule.days[i].isInHitch = true
                }
            }
        }
        
        // Apply off periods
        for offPeriod in plan.offPeriods {
            let startDate = offPeriod.start
            let endDate = offPeriod.end
            
            for i in 0..<schedule.days.count {
                let day = schedule.days[i]
                if isDateInRange(day.date, start: startDate, end: endDate) {
                    schedule.days[i].type = .earnedOffDay
                    schedule.days[i].notes = "Earned off day (micro-cycle)"
                    schedule.days[i].isOverride = false
                    schedule.days[i].isInHitch = false
                }
            }
        }
        
        // Apply training if specified
        if let training = plan.trainingPlacement {
            for i in 0..<schedule.days.count {
                let day = schedule.days[i]
                if isDateInRange(day.date, start: training.start, end: training.end) {
                    schedule.days[i].type = .training
                    schedule.days[i].notes = "Training (rescheduled to work period)"
                    schedule.days[i].isOverride = false
                    schedule.days[i].isInHitch = true
                }
            }
        }
        
        // Start new 14/7 cycle from final return date
        if let finalReturnIndex = schedule.days.firstIndex(where: { 
            calendar.isDate($0.date, inSameDayAs: plan.finalReturnDate) 
        }) {
            applyStandard14_7Pattern(&schedule, startingFrom: finalReturnIndex)
        }
    }
    
    /// Applies flexible reschedule plan to schedule while respecting manual overrides
    func applyFlexibleReschedulePlan(_ plan: FlexibleReschedulePlan, to schedule: inout WorkSchedule, startingFrom returnDate: Date) {
        // Validate plan before applying
        if let validationError = validateReschedulePlan(plan) {
            // Log warning - in production, this should be shown to user
            print("⚠️ Warning: \(validationError)")
        }
        
        let calendar = Calendar.current
        var currentDate = returnDate
        
        // Apply each flexible cycle
        for (cycleIndex, cycle) in plan.cycles.enumerated() {
            // Apply work days for this cycle
            let workStart = currentDate
            let workEnd = calendar.date(byAdding: .day, value: cycle.workDays - 1, to: workStart) ?? workStart
            
            for i in 0..<schedule.days.count {
                let day = schedule.days[i]
                if day.date >= workStart && day.date <= workEnd {
                    // SAFE ZONE: Only modify non-override days
                    if !day.isOverride {
                        schedule.days[i].type = .workday
                        schedule.days[i].notes = "Flexible reschedule - work period \(cycleIndex + 1)"
                        schedule.days[i].isOverride = false
                        schedule.days[i].isInHitch = true
                    }
                }
            }
            
            // Apply off days for this cycle
            let offStart = calendar.date(byAdding: .day, value: 1, to: workEnd) ?? workEnd
            let offEnd = calendar.date(byAdding: .day, value: cycle.offDays - 1, to: offStart) ?? offStart
            
            for i in 0..<schedule.days.count {
                let day = schedule.days[i]
                if day.date >= offStart && day.date <= offEnd {
                    // SAFE ZONE: Only modify non-override days
                    if !day.isOverride {
                        schedule.days[i].type = .earnedOffDay
                        schedule.days[i].notes = "Flexible reschedule - off period \(cycleIndex + 1)"
                        schedule.days[i].isOverride = false
                        schedule.days[i].isInHitch = false
                    }
                }
            }
            
            // Move to next cycle
            currentDate = calendar.date(byAdding: .day, value: cycle.totalDays, to: currentDate) ?? currentDate
        }
        
        // Start new 14/7 cycle from final return date
        if let finalReturnIndex = schedule.days.firstIndex(where: { 
            calendar.isDate($0.date, inSameDayAs: plan.finalReturnDate) 
        }) {
            applyStandard14_7Pattern(&schedule, startingFrom: finalReturnIndex)
        }
    }
    
    // MARK: - Enhanced Training Conflict Detection
    
    func detectTrainingConflicts(
        schedule: WorkSchedule,
        trainingStart: Date,
        trainingEnd: Date
    ) -> [ConflictInfo] {
        var conflicts: [ConflictInfo] = []
        let calendar = Calendar.current
        let hitchStartDate = schedule.hitchStartDate ?? schedule.startDate
        
        for day in schedule.days {
            // Use normalized date comparison
            if isDateInRange(day.date, start: trainingStart, end: trainingEnd) {
                let daysSinceStart = calendar.dateComponents([.day], from: hitchStartDate, to: day.date).day ?? 0
                let dayInCycle = (daysSinceStart % 21 + 21) % 21 // Ensure positive
                
                // Check if this would be an off day in the standard pattern
                if dayInCycle >= 14 {
                    let conflict = ConflictInfo(
                        conflictType: .trainingOnOffDay,
                        conflictDate: day.date,
                        suggestedResolution: nil, // Will be generated by planner
                        impactAssessment: "Training scheduled during off days - requires rescheduling"
                    )
                    conflicts.append(conflict)
                }
            }
        }
        
        return conflicts
    }
    
    // MARK: - Zero Earned Days Handler
    
    func handleZeroEarnedDaysScenario(
        interruptionStart: Date,
        interruptionEnd: Date,
        trainingPeriod: DateInterval?
    ) -> ReschedulePlan {
        // This is a special case where employee was on off days before interruption
        // All rescheduling must be self-funded through new work periods
        
        let workDeficit = 3 // Minimum work needed
        let targetReturnDay: WorkSchedule.Weekday? = .monday // Default to Monday crew change
        
        return planReschedule(
            interruptionEnd: interruptionEnd,
            trainingPeriod: trainingPeriod,
            targetReturnDay: targetReturnDay,
            workDeficit: workDeficit
        )
    }
    
    func applySmartReschedule(_ schedule: inout WorkSchedule, workedDays: Int, earnedDays: Int, preferredReturnDay: WorkSchedule.Weekday? = nil) {
        guard let interruptionEnd = schedule.interruptionEnd else { return }
        let calendar = Calendar.current
        let resumeDate = calendar.date(byAdding: .day, value: 1, to: interruptionEnd) ?? interruptionEnd
        guard let resumeIndex = schedule.days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: resumeDate) }) else {
            return
        }
        // 1. Work the minimum number of days after interruption to reach the preferred return day
        var workdaysAdded = 0
        var currentIndex = resumeIndex
        let minWorkdays = (workedDays < 14) ? (14 - workedDays) : 0
        // Work until the next preferred return day (after minWorkdays)
        while currentIndex < schedule.days.count {
            let currentDate = schedule.days[currentIndex].date
            let isHoliday = holidayService.isPublicHoliday(currentDate)
            if !isHoliday {
                schedule.days[currentIndex].type = .workday
                schedule.days[currentIndex].notes = "Rescheduled workday after interruption"
                schedule.days[currentIndex].isOverride = false
                schedule.days[currentIndex].isInHitch = true
                workdaysAdded += 1
            } else {
                schedule.days[currentIndex].notes = "Holiday during rescheduled work period"
                schedule.days[currentIndex].isInHitch = true
                schedule.days[currentIndex].isOverride = false
                workdaysAdded += 1
            }
            // After minimum workdays, check for preferred return day
            if let preferredDay = preferredReturnDay, workdaysAdded >= minWorkdays {
                if calendar.component(.weekday, from: currentDate) == preferredDay.rawValue {
                    currentIndex += 1 // Move to the next day for earned off day
                    break
                }
            }
            currentIndex += 1
        }
        // 2. Insert earned off day after rescheduled work (if 2:1 rule applies)
        let earnedOffDaysAfter = (workedDays < 14) ? earnedDays : 0
        if earnedOffDaysAfter > 0 && currentIndex < schedule.days.count {
            schedule.days[currentIndex].type = .earnedOffDay
            schedule.days[currentIndex].notes = "Earned off day after rescheduled work"
            schedule.days[currentIndex].isOverride = false
            schedule.days[currentIndex].isInHitch = false
            currentIndex += 1

        }
        // 3. Find the next preferred return day and start a new hitch
        if let preferredDay = preferredReturnDay {
            while currentIndex < schedule.days.count && calendar.component(.weekday, from: schedule.days[currentIndex].date) != preferredDay.rawValue {
                currentIndex += 1
            }
        }
        // 4. Start a new 14/7 hitch from the preferred return day (reset cycle)
        if currentIndex < schedule.days.count {
            applyStandard14_7Pattern(&schedule, startingFrom: currentIndex)
        }
    }
    
    // Apply standard 14/7 pattern starting from specified index
    private func applyStandard14_7Pattern(_ schedule: inout WorkSchedule, startingFrom index: Int) {
        let hitchCycle = 21 // 14 work days + 7 off days
        var dayInCycle = 0 // Always start new hitch from 0 after interruption
        for i in index..<schedule.days.count {
            if dayInCycle < 14 {
                schedule.days[i].type = .workday
                schedule.days[i].notes = "New hitch cycle - workday"
                schedule.days[i].isInHitch = true
            } else {
                schedule.days[i].type = .earnedOffDay
                schedule.days[i].notes = "New hitch cycle - off day"
                schedule.days[i].isInHitch = false
            }
            schedule.days[i].isOverride = false // Clear any previous override
            dayInCycle = (dayInCycle + 1) % hitchCycle
        }
    }
    
    private func calculateRemainingWorkdays(_ workedDays: Int) -> Int {
        // Based on the 14:7 hitch pattern
        if workedDays >= 14 {
            return 14 // Start a new full hitch
        } else {
            return 14 - workedDays // Complete the current hitch
        }
    }
    
    private func findNextDateWithWeekday(after date: Date, weekday: WorkSchedule.Weekday) -> Date {
        let calendar = Calendar.current
        var currentDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        
        // Loop until we find the preferred weekday
        while calendar.component(.weekday, from: currentDate) != weekday.rawValue {
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return currentDate
    }
    
    // MARK: - Manual Override Support
    
    func applyManualOverride(_ schedule: inout WorkSchedule, for date: Date, type: DayType, notes: String? = nil) {
        let calendar = Calendar.current
        // Find the day in the schedule
        if let index = schedule.days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            // Mark the day with the new type
            schedule.days[index].type = type
            schedule.days[index].isOverride = true
            schedule.days[index].notes = notes ?? "Manual override"
            // Mark the schedule as manually adjusted to prevent auto-rescheduling
            schedule.manuallyAdjusted = true
        }
    }
    
    func resetManualAdjustments(_ schedule: inout WorkSchedule) {
        // Clear manual adjustment flag
        schedule.manuallyAdjusted = false
        
        // Remove all overrides in the schedule
        for i in 0..<schedule.days.count {
            if schedule.days[i].isOverride {
                // Reset to default pattern
                let calendar = Calendar.current
                let daysSinceStart = calendar.dateComponents([.day], from: schedule.startDate, to: schedule.days[i].date).day ?? 0
                let dayInCycle = daysSinceStart % 21
                
                schedule.days[i].type = determineDayTypeInHitchPattern(dayInCycle)
                schedule.days[i].isOverride = false
                schedule.days[i].notes = nil
            }
        }
    }
    
    // MARK: - Validation System
    
    /// Validates a FlexibleReschedulePlan and returns error message if invalid
    public func validateReschedulePlan(_ plan: FlexibleReschedulePlan) -> String? {
        // Check each cycle
        for (index, cycle) in plan.cycles.enumerated() {
            if cycle.workDays < 5 {
                return "Cycle \(index + 1) has only \(cycle.workDays) work days, which is below the minimum of 5. This may make travel and scheduling impractical."
            }
            if cycle.workDays > 14 {
                return "Cycle \(index + 1) has \(cycle.workDays) work days, which exceeds the standard 14-day cycle. This usually requires supervisor approval."
            }
            if cycle.offDays < 2 {
                return "Cycle \(index + 1) has only \(cycle.offDays) off days, which is below the minimum of 2."
            }
            
            // Check ratio for each cycle
            if let ratioError = checkWorkOffRatio(workDays: cycle.workDays, offDays: cycle.offDays) {
                return "Cycle \(index + 1): \(ratioError)"
            }
        }
        
        // Check overall ratio
        if plan.totalWorkDays > 0 && plan.totalOffDays > 0 {
            if let ratioError = checkWorkOffRatio(workDays: plan.totalWorkDays, offDays: plan.totalOffDays) {
                return "Overall schedule: \(ratioError)"
            }
        }
        
        return nil
    }
    
    /// Validates a ReschedulePlan (legacy) and returns error message if invalid
    public func validateReschedulePlan(_ plan: ReschedulePlan) -> String? {
        if plan.totalWorkDays < 5 {
            return "Total work days (\(plan.totalWorkDays)) is below the minimum of 5. This may make travel and scheduling impractical."
        }
        if plan.totalWorkDays > 14 {
            return "Total work days (\(plan.totalWorkDays)) exceeds the standard 14-day cycle. This usually requires supervisor approval."
        }
        if plan.totalOffDays < 2 {
            return "Total off days (\(plan.totalOffDays)) is below the minimum of 2."
        }
        
        // Check overall ratio
        if let ratioError = checkWorkOffRatio(workDays: plan.totalWorkDays, offDays: plan.totalOffDays) {
            return ratioError
        }
        
        return nil
    }
    
    /// Validates work/off ratio and returns error message if invalid
    public func checkWorkOffRatio(workDays: Int, offDays: Int) -> String? {
        guard workDays > 0 && offDays > 0 else {
            return "Work days and off days must both be greater than 0."
        }
        
        let ratio = Double(workDays) / Double(offDays)
        
        if ratio < 1.5 {
            return "Work/off ratio (\(String(format: "%.1f", ratio)):1) is below the recommended minimum of 1.5:1."
        }
        
        if ratio > 3.0 {
            return "Work/off ratio (\(String(format: "%.1f", ratio)):1) exceeds the recommended maximum of 3:1."
        }
        
        return nil
    }
    
    /// Validates an interruption period setup and returns warnings if any
    public func validateInterruptionPeriod(startDate: Date, endDate: Date, earnedDays: Int) -> [String] {
        var warnings: [String] = []
        let calendar = Calendar.current
        
        // Calculate total interruption days
        let totalDays = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        let totalInterruptionDays = totalDays + 1 // Include both start and end date
        
        // Check if earned days are sufficient
        if earnedDays > totalInterruptionDays {
            warnings.append("Earned off days (\(earnedDays)) exceed total interruption days (\(totalInterruptionDays)). This may indicate a calculation error.")
        }
        
        // Check if interruption is too long
        if totalInterruptionDays > 30 {
            warnings.append("Interruption period is very long (\(totalInterruptionDays) days). Please verify this is correct.")
        }
        
        return warnings
    }
    
    // MARK: - Helper Functions
    
    func checkTrainingOverlapsOffDays(_ schedule: WorkSchedule, startDate: Date, endDate: Date) -> Bool {
        let calendar = Calendar.current
        let hitchStartDate = schedule.hitchStartDate ?? schedule.startDate
        
        for day in schedule.days {
            // Use normalized date comparison
            if isDateInRange(day.date, start: startDate, end: endDate) {
                let daysSinceStart = calendar.dateComponents([.day], from: hitchStartDate, to: day.date).day ?? 0
                let dayInCycle = (daysSinceStart % 21 + 21) % 21 // Ensure positive
                
                // Check if this would be an off day in the standard pattern
                if dayInCycle >= 14 {
                    return true
                }
            }
        }
        
        return false
    }
    
    func calculateVacationDaysUsed(_ schedule: WorkSchedule, startDate: Date, endDate: Date) -> Int {
        // Get earned off days before interruption from the current hitch only
        let earnedOffDays = schedule.earnedOffDaysBeforeInterruption ?? 0
        
        // Count total days in interruption
        let calendar = Calendar.current
        let totalDays = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        let totalInterruptionDays = totalDays + 1  // Include both start and end date
        
        // First, apply earned days from the current hitch cycle
        // Vacation days are counted after earned off days are used
        let actualVacationDays = max(0, totalInterruptionDays - earnedOffDays)
        
        return actualVacationDays
    }
    
    func removeInterruption(_ schedule: inout WorkSchedule) {
        guard schedule.isInterrupted,
              let start = schedule.interruptionStart,
              let _ = schedule.interruptionEnd else {
            return
        }
        
        // Clear interruption status
        schedule.isInterrupted = false
        schedule.interruptionStart = nil
        schedule.interruptionEnd = nil
        schedule.interruptionType = nil
        schedule.preferredReturnDay = nil
        schedule.earnedOffDaysBeforeInterruption = nil
        schedule.workedDaysBeforeInterruption = nil
        
        // Reset manuallyAdjusted flag when removing interruption
        // This ensures future interruptions can be processed normally and warnings will show
        schedule.manuallyAdjusted = false
        
        // Instead of just resetting overridden days, we'll properly recalculate
        // the entire schedule based on the startDate
        
        // Store original startDate to maintain correct hitch pattern
        let originalStartDate = schedule.startDate
        
        // Reset all days from the interruption period and after
        for i in 0..<schedule.days.count {
            let day = schedule.days[i]
            if normalizeToStartOfDay(day.date) >= normalizeToStartOfDay(start) {
                // Calculate the correct day type based on the 14/7 cycle
                let calendar = Calendar.current
                let daysSinceStart = calendar.dateComponents([.day], from: originalStartDate, to: day.date).day ?? 0
                let dayInCycle = daysSinceStart % 21
                
                // Check if it's a holiday first
                if holidayService.isPublicHoliday(day.date) {
                    // Keep holiday designation but reset notes and override flag
                    if let holidayType = holidayService.getHolidayType(day.date) {
                        schedule.days[i].type = convertHolidayTypeToDayType(holidayType)
                    }
                    schedule.days[i].notes = "Holiday"
                    // Set isInHitch based on whether the holiday falls in work period or off period
                    schedule.days[i].isInHitch = dayInCycle < 14
                } else {
                    // Reset to standard pattern
                    schedule.days[i].type = determineDayTypeInHitchPattern(dayInCycle)
                    schedule.days[i].notes = nil
                    // Set isInHitch based on the day's position in the 21-day cycle
                    schedule.days[i].isInHitch = dayInCycle < 14
                }
                
                // Clear override flag and other interruption-related attributes
                schedule.days[i].isOverride = false
                
                // Reapply holiday pay rules if applicable
                if schedule.days[i].type == .eidHoliday || 
                   schedule.days[i].type == .nationalDay || 
                   schedule.days[i].type == .foundingDay {
                    
                    let is7thOr14thWorkday = (dayInCycle == 6 || dayInCycle == 13)
                    
                    if is7thOr14thWorkday {
                        schedule.days[i].overtimeHours = 8.0
                        schedule.days[i].notes = "Holiday on 7th/14th workday - 8hrs straight time"
                    } else if dayInCycle < 14 {
                        schedule.days[i].overtimeHours = 12.0
                        schedule.days[i].notes = "Holiday during workday - 12hrs overtime"
                    }
                }
            }
        }
    }
    
    // Function to get the current day in the hitch cycle (0-20)
    func getCurrentHitchDay(_ schedule: WorkSchedule, for date: Date) -> Int {
        let calendar = Calendar.current
        let hitchStartDate = schedule.hitchStartDate ?? schedule.startDate
        let normalizedHitchStart = normalizeToStartOfDay(hitchStartDate)
        let normalizedDate = normalizeToStartOfDay(date)
        let daysSinceStart = calendar.dateComponents([.day], from: normalizedHitchStart, to: normalizedDate).day ?? 0
        return (daysSinceStart % 21 + 21) % 21 // Ensure positive
    }
    
    // MARK: - Recalculate Overtime Hours
    
    /// Recalculates overtime and ADL hours for all days in a schedule based on the hitch start date
    /// This fixes schedules that were generated before the hitchStartDate fix
    /// CRITICAL FIX: Also corrects day.type if it doesn't match the dayInCycle pattern
    func recalculateOvertimeHours(_ schedule: inout WorkSchedule) {
        guard let hitchStartDate = schedule.hitchStartDate else {
            AppLogger.engine.warning("Cannot recalculate overtime: hitchStartDate is nil")
            return // Can't recalculate without hitch start date
        }
        
        let calendar = Calendar.current
        let normalizedHitchStart = normalizeToStartOfDay(hitchStartDate)
        let hitchCycle = 21 // 14 on, 7 off
        
        AppLogger.engine.info("Recalculating overtime hours. Hitch start: \(hitchStartDate.formatted(date: .abbreviated, time: .omitted))")
        
        for i in 0..<schedule.days.count {
            let day = schedule.days[i]
            let normalizedDayDate = normalizeToStartOfDay(day.date)
            
            // Calculate dayInCycle based on hitch start date
            let daysSinceHitchStart = calendar.dateComponents([.day], from: normalizedHitchStart, to: normalizedDayDate).day ?? 0
            let dayInCycle = (daysSinceHitchStart % hitchCycle + hitchCycle) % hitchCycle // Ensure positive
            
            // CRITICAL FIX: Determine what the day type SHOULD be based on dayInCycle
            let expectedType = determineDayTypeInHitchPattern(dayInCycle)
            
            // Check if day type needs correction (unless it's a holiday or override)
            let isHolidayType = (day.type == .eidHoliday || day.type == .nationalDay || day.type == .foundingDay)
            
            if !day.isOverride && !isHolidayType && day.type != expectedType {
                // Day type is wrong - correct it FIRST before calculating overtime
                schedule.days[i].type = expectedType
                AppLogger.engine.info("Corrected day type for \(day.date.formatted(date: .numeric, time: .omitted)): was \(day.type.rawValue), now \(expectedType.rawValue), dayInCycle=\(dayInCycle)")
            }
            
            // Recalculate overtime based on dayInCycle, regardless of current day.type
            if dayInCycle < 14 && !day.isOverride {
                // This is a workday in the cycle - calculate overtime
                let isHoliday = holidayService.isPublicHoliday(day.date)
                let overtime = computeOvertime(for: expectedType, dayInCycle: dayInCycle, isHoliday: isHoliday)
                let adl = computeAdl(for: expectedType, dayInCycle: dayInCycle, isHoliday: isHoliday)
                
                schedule.days[i].overtimeHours = overtime
                schedule.days[i].adlHours = adl
                schedule.days[i].isInHitch = true
            } else if dayInCycle >= 14 && !day.isOverride {
                // This is an off day in the cycle - zero overtime
                schedule.days[i].overtimeHours = 0
                schedule.days[i].adlHours = 0
                schedule.days[i].isInHitch = false
            }
        }
        
        AppLogger.engine.info("Overtime recalculation complete")
    }
    
    // MARK: - Holiday Pay Handling
    
    func handleHolidayPayRules(_ schedule: inout WorkSchedule) {
        for i in 0..<schedule.days.count {
            let day = schedule.days[i]
            let dayInCycle = getCurrentHitchDay(schedule, for: day.date)
            
            // Is this day a holiday?
            let isHoliday = (day.type == .eidHoliday || day.type == .nationalDay || day.type == .foundingDay)
            
            if isHoliday {
                // Is it the 7th or 14th day of work?
                let is7thOr14thWorkday = (dayInCycle == 6 || dayInCycle == 13)
                
                if is7thOr14thWorkday {
                    // Special pay rule: 8 hours straight time only
                    schedule.days[i].overtimeHours = 8.0
                    schedule.days[i].notes = "Holiday on 7th/14th workday - 8hrs straight time"
                } else if dayInCycle < 14 {
                    // Regular holiday during work period: 12 hours overtime
                    schedule.days[i].overtimeHours = 12.0
                    schedule.days[i].notes = "Holiday during workday - 12hrs overtime"
                }
                // Note: Holidays during off days have no special pay - no change needed
            }
        }
    }
}

    private func computeOvertime(for type: DayType, dayInCycle: Int, isHoliday: Bool) -> Double {
        guard dayInCycle < 14 else { return 0 }
        if isHoliday {
            return 12
        } else if dayInCycle == 6 || dayInCycle == 13 {
            return 12
        } else {
            return 4
        }
    }

    private func computeAdl(for type: DayType, dayInCycle: Int, isHoliday: Bool) -> Double {
        guard dayInCycle < 14 else { return 0 }
        // 3-hour allowance on first and last hitch day
        if dayInCycle == 0 || dayInCycle == 13 {
            return 3
        } else {
            return 0
        }
    }

