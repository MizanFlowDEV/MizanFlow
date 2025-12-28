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
            totalOvertimeHours: 0,
            expectedOvertimeHours: 0
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
                expectedOvertime: calculateExpectedOvertime(dayInCycle: dayInCycle, isHoliday: day.isHoliday),
                daysSinceHitchStart: daysSinceHitchStart
            )
            
            if day.type == .workday {
                report.workDays.append(dayInfo)
            } else {
                report.offDays.append(dayInfo)
            }
            
            report.totalOvertimeHours += day.overtimeHours ?? 0
            report.expectedOvertimeHours += dayInfo.expectedOvertime
        }
        
        return report
    }
    
    private func calculateExpectedOvertime(dayInCycle: Int, isHoliday: Bool) -> Double {
        guard dayInCycle < 14 else { return 0 }
        if isHoliday {
            return 12
        } else if dayInCycle == 6 || dayInCycle == 13 {
            return 12
        } else {
            return 4
        }
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
    var expectedOvertimeHours: Double = 0
    
    var discrepancy: Double {
        expectedOvertimeHours - totalOvertimeHours
    }
    
    func printReport() {
        print("=== SALARY DIAGNOSTIC REPORT ===")
        if let error = error {
            print("ERROR: \(error)")
            return
        }
        
        print("Month: \(month?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")")
        print("Hitch Start Date: \(hitchStartDate?.formatted(date: .abbreviated, time: .omitted) ?? "NOT SET")")
        print("Schedule Start Date: \(scheduleStartDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")")
        print("Total Days: \(totalDays)")
        print("Work Days: \(workDays.count)")
        print("Off Days: \(offDays.count)")
        print("\n--- WORK DAYS ---")
        for day in workDays {
            let dateStr = day.date.formatted(date: .numeric, time: .omitted)
            print("\(dateStr): dayInCycle=\(day.dayInCycle), OT=\(day.overtimeHours) (expected: \(day.expectedOvertime)), daysSinceHitch=\(day.daysSinceHitchStart)")
            if day.overtimeHours != day.expectedOvertime {
                print("  ⚠️ MISMATCH: Expected \(day.expectedOvertime) but got \(day.overtimeHours)")
            }
        }
        print("\n--- SUMMARY ---")
        print("Total Overtime Hours: \(totalOvertimeHours)")
        print("Expected Overtime Hours: \(expectedOvertimeHours)")
        print("Discrepancy: \(discrepancy) hours")
        print("================================")
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
    let expectedOvertime: Double
    let daysSinceHitchStart: Int
}
