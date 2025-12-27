import Foundation

struct BudgetEntry: Identifiable, Codable {
    var id: UUID
    var entryDescription: String
    var category: BudgetCategory
    var amount: Double
    var date: Date
    var notes: String?
    var isIncome: Bool
    var isRecurring: Bool
    var recurrenceInterval: RecurrenceInterval?
    
    enum BudgetCategory: String, Codable, CaseIterable {
        case housing
        case transportation
        case utilities
        case groceries
        case entertainment
        case savings
        case investments
        case healthcare
        case education
        case other
        
        var icon: String {
            switch self {
            case .housing: return "house.fill"
            case .transportation: return "car.fill"
            case .utilities: return "bolt.fill"
            case .groceries: return "cart.fill"
            case .entertainment: return "tv.fill"
            case .savings: return "banknote.fill"
            case .investments: return "chart.line.uptrend.xyaxis"
            case .healthcare: return "heart.fill"
            case .education: return "book.fill"
            case .other: return "ellipsis.circle.fill"
            }
        }
    }
    
    enum RecurrenceInterval: String, Codable {
        case daily
        case weekly
        case monthly
        case yearly
    }
    
    init(category: BudgetCategory, amount: Double, date: Date = Date(), entryDescription: String = "", isIncome: Bool = false, notes: String? = nil) {
        self.id = UUID()
        self.entryDescription = entryDescription
        self.category = category
        self.amount = amount
        self.date = date
        self.isIncome = isIncome
        self.isRecurring = false
        self.notes = notes
    }
} 