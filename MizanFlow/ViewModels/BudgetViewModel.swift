import Foundation
import SwiftUI

@MainActor
class BudgetViewModel: ObservableObject {
    @Published var budgetEntries: [BudgetEntry] = []
    @Published var selectedMonth: Date = Date()
    @Published var showingAddEntrySheet = false
    @Published var showingEditEntrySheet = false
    @Published var selectedEntry: BudgetEntry?
    
    private let dataService = DataPersistenceService.shared
    
    init() {
        loadBudgetEntries()
    }
    
    private func loadBudgetEntries() {
        // In a real app, this would load from Core Data
        // For now, we'll use sample data
        budgetEntries = [
            BudgetEntry(category: .housing, amount: 5000, entryDescription: "Rent", isIncome: false),
            BudgetEntry(category: .transportation, amount: 1000, entryDescription: "Gas", isIncome: false),
            BudgetEntry(category: .utilities, amount: 500, entryDescription: "Electricity", isIncome: false),
            BudgetEntry(category: .groceries, amount: 2000, entryDescription: "Weekly groceries", isIncome: false),
            BudgetEntry(category: .savings, amount: 3000, entryDescription: "Savings", isIncome: false)
        ]
    }
    
    func addEntry(entryDescription: String, amount: Double, category: String, isIncome: Bool, notes: String? = nil) {
        guard let budgetCategory = BudgetEntry.BudgetCategory(rawValue: category.lowercased()) else {
            return
        }
        
        let newEntry = BudgetEntry(
            category: budgetCategory,
            amount: amount,
            date: selectedMonth,
            entryDescription: entryDescription,
            isIncome: isIncome,
            notes: notes
        )
        
        budgetEntries.append(newEntry)
        saveBudgetEntries()
    }
    
    func updateEntry(_ entry: BudgetEntry, entryDescription: String, amount: Double, category: String, isIncome: Bool, notes: String? = nil) {
        guard let budgetCategory = BudgetEntry.BudgetCategory(rawValue: category.lowercased()) else {
            return
        }
        
        if let index = budgetEntries.firstIndex(where: { $0.id == entry.id }) {
            var updatedEntry = entry
            updatedEntry.entryDescription = entryDescription
            updatedEntry.amount = amount
            updatedEntry.category = budgetCategory
            updatedEntry.isIncome = isIncome
            updatedEntry.notes = notes
            
            budgetEntries[index] = updatedEntry
            saveBudgetEntries()
        }
    }
    
    func deleteEntry(_ entry: BudgetEntry) {
        budgetEntries.removeAll { $0.id == entry.id }
        saveBudgetEntries()
    }
    
    private func saveBudgetEntries() {
        // In a real app, this would save to Core Data
    }
    
    // MARK: - Calculation Methods
    
    func getTotalForCategory(_ category: BudgetEntry.BudgetCategory) -> Double {
        budgetEntries.filter { $0.category == category }.reduce(0) { $0 + $1.amount }
    }
    
    func getTotalBudget() -> Double {
        budgetEntries.reduce(0) { $0 + $1.amount }
    }
    
    func getPercentageForCategory(_ category: BudgetEntry.BudgetCategory) -> Double {
        let total = getTotalBudget()
        guard total > 0 else { return 0 }
        return (getTotalForCategory(category) / total) * 100
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
    
    // MARK: - Filtering Methods
    
    var entriesForMonth: [BudgetEntry] {
        getEntriesForMonth(selectedMonth)
    }
    
    func getEntriesForMonth(_ date: Date) -> [BudgetEntry] {
        let calendar = Calendar.current
        return budgetEntries.filter { entry in
            calendar.isDate(entry.date, equalTo: date, toGranularity: .month)
        }
    }
    
    func getEntriesForCategory(_ category: BudgetEntry.BudgetCategory) -> [BudgetEntry] {
        budgetEntries.filter { $0.category == category }
    }
    
    // MARK: - Budget Analysis
    
    var totalIncome: Double {
        entriesForMonth.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    
    var totalExpenses: Double {
        entriesForMonth.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    
    var netBalance: Double {
        totalIncome - totalExpenses
    }
    
    var savingsRate: Double {
        guard totalIncome > 0 else { return 0 }
        return (netBalance / totalIncome) * 100
    }
    
    var categoryBreakdown: [(category: String, amount: Double, percentage: Double)] {
        let expenses = entriesForMonth.filter { !$0.isIncome }
        let totalExpensesAmount = expenses.reduce(0) { $0 + $1.amount }
        
        let categoriesMap = Dictionary(grouping: expenses) { $0.category.rawValue }
        
        return categoriesMap.map { (category, entries) in
            let amount = entries.reduce(0) { $0 + $1.amount }
            let percentage = totalExpensesAmount > 0 ? (amount / totalExpensesAmount) * 100 : 0
            return (category, amount, percentage)
        }
        .sorted(by: { $0.amount > $1.amount })
    }
    
    func getMonthlyTrend(for category: BudgetEntry.BudgetCategory) -> [(month: Date, amount: Double)] {
        // In a real app, this would analyze historical data
        // For now, return sample data
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        
        return (1...6).map { monthOffset in
            let month = (currentMonth - monthOffset + 12) % 12 + 1
            let date = calendar.date(from: DateComponents(year: 2024, month: month)) ?? Date()
            let amount = Double.random(in: 1000...5000) // Sample data
            return (date, amount)
        }
    }
    
    func updateMonth(_ date: Date) {
        selectedMonth = date
    }
} 