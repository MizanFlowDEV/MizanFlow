import Foundation

enum DayType: String, Codable {
    case workday
    case earnedOffDay
    case vacation
    case training
    case eidHoliday
    case nationalDay
    case foundingDay
    case autoRescheduled
    case companyOff
    case manualOverride
    case ramadan
    
    var color: String {
        switch self {
        case .workday: return "workdayGreen"
        case .earnedOffDay: return "offDayGray"
        case .vacation: return "vacationYellow"
        case .training: return "trainingOrange"
        case .eidHoliday: return "eidGold"
        case .nationalDay: return "nationalNavy"
        case .foundingDay: return "foundingMaroon"
        case .autoRescheduled: return "rescheduledBlue"
        case .companyOff: return "companyOffTeal"
        case .manualOverride: return "overrideRed"
        case .ramadan: return "ramadanGray"
        }
    }
    
    var description: String {
        switch self {
        case .workday: return "Regular Working Day"
        case .earnedOffDay: return "Earned Off Day"
        case .vacation: return "Leave/Vacation"
        case .training: return "Training Day"
        case .eidHoliday: return "Eid Holiday"
        case .nationalDay: return "National Day"
        case .foundingDay: return "Founding Day"
        case .autoRescheduled: return "Rescheduled Day (Auto)"
        case .companyOff: return "Company-Initiated Day Off"
        case .manualOverride: return "Manual Override"
        case .ramadan: return "Ramadan"
        }
    }
}

struct WorkSchedule: Identifiable, Codable {
    var id: UUID
    var startDate: Date
    var endDate: Date
    var days: [ScheduleDay]
    var isInterrupted: Bool
    var interruptionStart: Date?
    var interruptionEnd: Date?
    var interruptionType: InterruptionType?
    var preferredReturnDay: Weekday?
    var earnedOffDaysBeforeInterruption: Int?
    var workedDaysBeforeInterruption: Int?
    var manuallyAdjusted: Bool = false
    var vacationBalance: Int = 30 // Default annual balance
    var hitchStartDate: Date?
    
    struct ScheduleDay: Identifiable, Codable {
        var id: UUID
        var date: Date
        var type: DayType
        /// true if this date is a public holiday (even if it falls in a work hitch)
        var isHoliday: Bool
        var isOverride: Bool
        var notes: String?
        var overtimeHours: Double?
        /// baked Additional Straight Time (ADL) hours for this day
        var adlHours: Double?
        var isInHitch: Bool = true
        var hasIcon: Bool = false
        var iconName: String? = nil
        /// true if this is a placeholder day before hitch start (for UI display only)
        var isPlaceholder: Bool? = nil
    }
    
    enum InterruptionType: String, Codable {
        case shortLeave
        case vacation
        case training
        case companyOff
    }
    
    enum Weekday: Int, Codable, CaseIterable {
        case sunday = 1
        case monday = 2
        case tuesday = 3
        case wednesday = 4
        case thursday = 5
        case friday = 6
        case saturday = 7
        
        var description: String {
            switch self {
            case .sunday: return "Sunday"
            case .monday: return "Monday"
            case .tuesday: return "Tuesday"
            case .wednesday: return "Wednesday"
            case .thursday: return "Thursday"
            case .friday: return "Friday"
            case .saturday: return "Saturday"
            }
        }
        
        var localizedName: String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: UserDefaults.standard.string(forKey: "appLanguage") ?? Locale.current.identifier)
            return formatter.weekdaySymbols[self.rawValue - 1]
        }
    }
    
    init(startDate: Date) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = Calendar.current.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        self.days = []
        self.isInterrupted = false
        self.manuallyAdjusted = false
        self.hitchStartDate = nil
    }
}