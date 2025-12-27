import Foundation
import UserNotifications

class SmartAlertService {
    static let shared = SmartAlertService()
    private let holidayService = HolidayService.shared
    private init() {}
    
    enum AlertType {
        case lowOffDays(remaining: Int)
        case salarySpike(percentage: Double)
        case salaryDrop(percentage: Double)
        case holidayConflict(date: Date)
        case monthlySuggestion(message: String)
        
        var title: String {
            switch self {
            case .lowOffDays: return "Low Off Days"
            case .salarySpike: return "Salary Increase"
            case .salaryDrop: return "Salary Decrease"
            case .holidayConflict: return "Holiday Conflict"
            case .monthlySuggestion: return "Monthly Suggestion"
            }
        }
        
        var message: String {
            switch self {
            case .lowOffDays(let remaining):
                return "You have only \(remaining) off days remaining this month."
            case .salarySpike(let percentage):
                return "Your salary has increased by \(String(format: "%.1f", percentage))% this month."
            case .salaryDrop(let percentage):
                return "Your salary has decreased by \(String(format: "%.1f", percentage))% this month."
            case .holidayConflict(let date):
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "There's a holiday conflict on \(formatter.string(from: date))."
            case .monthlySuggestion(let message):
                return message
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleAlert(_ type: AlertType, date: Date? = nil) {
        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = type.message
        content.sound = .default
        
        var trigger: UNNotificationTrigger?
        
        if let date = date {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        } else {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        }
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func checkLowOffDays(_ schedule: WorkSchedule, threshold: Int) {
        let calendar = Calendar.current
        let today = Date()
        
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return
        }
        
        let remainingOffDays = schedule.days.filter { day in
            day.date >= today && day.date <= monthEnd && day.type == .earnedOffDay
        }.count
        
        if remainingOffDays <= threshold {
            scheduleAlert(.lowOffDays(remaining: remainingOffDays))
        }
    }
    
    func checkSalaryChanges(_ currentSalary: Double, previousSalary: Double) {
        let percentageChange = ((currentSalary - previousSalary) / previousSalary) * 100
        
        if percentageChange >= 10 {
            scheduleAlert(.salarySpike(percentage: percentageChange))
        } else if percentageChange <= -10 {
            scheduleAlert(.salaryDrop(percentage: abs(percentageChange)))
        }
    }
    
    func checkHolidayConflicts(_ schedule: WorkSchedule) {
        let today = Date()
        
        for day in schedule.days where day.date >= today {
            if day.type == .workday {
                let isHoliday = holidayService.isHoliday(day.date)
                
                if isHoliday {
                    scheduleAlert(.holidayConflict(date: day.date))
                }
            }
        }
    }
    
    func generateMonthlySuggestion(_ schedule: WorkSchedule, salary: SalaryBreakdown) {
        let today = Date()
        
        guard let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: today)),
              let monthEnd = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return
        }
        
        let workDays = schedule.days.filter { day in
            day.date >= monthStart && day.date <= monthEnd && day.type == .workday
        }.count
        
        let offDays = schedule.days.filter { day in
            day.date >= monthStart && day.date <= monthEnd && day.type == .earnedOffDay
        }.count
        
        var suggestions: [String] = []
        
        if workDays > 14 {
            suggestions.append("Consider taking some earned off days to maintain work-life balance.")
        }
        
        if offDays < 7 {
            suggestions.append("You have fewer off days than usual this month.")
        }
        
        if salary.overtimeHours > 40 {
            suggestions.append("You've worked significant overtime this month. Remember to take breaks.")
        }
        
        if let suggestion = suggestions.randomElement() {
            scheduleAlert(.monthlySuggestion(message: suggestion))
        }
    }
} 
