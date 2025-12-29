import Foundation

/// Diagnostic tool to trace salary calculation issues
class SalaryDiagnostics {
    static let shared = SalaryDiagnostics()
    private init() {}
    
    /// Diagnoses overtime calculation for a specific month
    func diagnoseOvertimeCalculation(for schedule: WorkSchedule, month: Date) -> DiagnosticReport {
        let calendar = Calendar.current
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return DiagnosticReport(error: "Failed to calculate month boundaries")
        }
        
        let normalizedMonthStart = Calendar.current.startOfDay(for: monthStart)
        let normalizedMonthEnd = Calendar.current.startOfDay(for: monthEnd)
        
        // Filter November days
        let monthDays = schedule.days.filter { day in
            let normalizedDayDate = Calendar.current.startOfDay(for: day.date)
            return normalizedDayDate >= normalizedMonthStart && normalizedDayDate <= normalizedMonthEnd
        }
        
        var report = DiagnosticReport(
            month: month,
            hitchStartDate: schedule.hitchStartDate,
            scheduleStartDate: schedule.startDate,
            totalDays: monthDays.count,
            workDays: [],
            offDays: [],
            totalOvertimeHours: 0
        )
        
        let hitchCycle = 21
        let normalizedHitchStart = schedule.hitchStartDate != nil 
            ? Calendar.current.startOfDay(for: schedule.hitchStartDate!)
            : Calendar.current.startOfDay(for: schedule.startDate)
        
        for day in monthDays.sorted(by: { $0.date < $1.date }) {
            let normalizedDayDate = Calendar.current.startOfDay(for: day.date)
            let daysSinceHitchStart = calendar.dateComponents([.day], from: normalizedHitchStart, to: normalizedDayDate).day ?? 0
            let dayInCycle = (daysSinceHitchStart % hitchCycle + hitchCycle) % hitchCycle
            
            let dayInfo = DayInfo(
                date: day.date,
                type: day.type,
                dayInCycle: dayInCycle,
                overtimeHours: day.overtimeHours ?? 0,
                adlHours: day.adlHours ?? 0,
                isOverride: day.isOverride,
                isInHitch: day.isInHitch,
                daysSinceHitchStart: daysSinceHitchStart
            )
            
            if day.type == .workday {
                report.workDays.append(dayInfo)
            } else {
                report.offDays.append(dayInfo)
            }
            
            // Only count overtime from actual work days, matching what the schedule view shows
            // Trust the schedule's day.type - if it says vacation/off, don't count it
            let isWorkDayType = (day.type == .workday || day.type == .eidHoliday || 
                                day.type == .nationalDay || day.type == .foundingDay)
            
            if isWorkDayType {
                // Count the actual overtime hours stored in the schedule
                report.totalOvertimeHours += day.overtimeHours ?? 0
            }
        }
        
        return report
    }
}

struct DiagnosticReport {
    var error: String?
    var month: Date?
    var hitchStartDate: Date?
    var scheduleStartDate: Date?
    var totalDays: Int = 0
    var workDays: [DayInfo] = []
    var offDays: [DayInfo] = []
    var totalOvertimeHours: Double = 0
    
    func printReport() {
        AppLogger.engine.info("=== SALARY DIAGNOSTIC REPORT ===")
        if let error = error {
            AppLogger.engine.error("ERROR: \(error)")
            return
        }
        
        AppLogger.engine.info("Month: \(month?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")")
        AppLogger.engine.info("Hitch Start Date: \(hitchStartDate?.formatted(date: .abbreviated, time: .omitted) ?? "NOT SET")")
        AppLogger.engine.info("Schedule Start Date: \(scheduleStartDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")")
        AppLogger.engine.info("Total Days: \(totalDays), Work Days: \(workDays.count), Off Days: \(offDays.count)")
        
        AppLogger.engine.debug("--- WORK DAYS ---")
        for day in workDays {
            let dateStr = day.date.formatted(date: .numeric, time: .omitted)
            AppLogger.engine.debug("\(dateStr): dayInCycle=\(day.dayInCycle), OT=\(day.overtimeHours), ADL=\(day.adlHours), daysSinceHitch=\(day.daysSinceHitchStart)")
        }
        
        AppLogger.engine.info("--- SUMMARY --- Total Overtime Hours: \(totalOvertimeHours)")
        AppLogger.engine.info("================================")
    }
}

struct DayInfo {
    let date: Date
    let type: DayType
    let dayInCycle: Int
    let overtimeHours: Double
    let adlHours: Double
    let isOverride: Bool
    let isInHitch: Bool
    let daysSinceHitchStart: Int
}
