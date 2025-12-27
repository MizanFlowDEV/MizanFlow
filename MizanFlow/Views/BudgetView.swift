import SwiftUI

struct BudgetView: View {
    @StateObject private var viewModel = BudgetViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingMonthPicker = false
    @State private var tempMonth = Date()
    @FocusState private var focusedField: Field?
    
    enum Field {
        case amount
        case notes
    }
    
    var body: some View {
        NavigationView {
            List {
                // Month Selector
                Section {
                    Button(action: {
                        tempMonth = viewModel.selectedMonth
                        showingMonthPicker = true
                    }) {
                        HStack {
                            Text("Select Month")
                            Spacer()
                            Text(viewModel.formatMonth(viewModel.selectedMonth))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Month")
                }
                
                // Income Section
                Section {
                    ForEach(viewModel.entriesForMonth.filter { $0.isIncome }) { entry in
                        BudgetEntryRow(entry: entry, viewModel: viewModel)
                    }
                    
                    HStack {
                        Text("Total Income")
                            .bold()
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.totalIncome))
                            .bold()
                    }
                } header: {
                    Text("Income")
                }
                
                // Expenses Section
                Section {
                    ForEach(viewModel.entriesForMonth.filter { !$0.isIncome }) { entry in
                        BudgetEntryRow(entry: entry, viewModel: viewModel)
                    }
                    
                    HStack {
                        Text("Total Expenses")
                            .bold()
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.totalExpenses))
                            .bold()
                    }
                } header: {
                    Text("Expenses")
                }
                
                // Summary Section
                Section {
                    HStack {
                        Text("Net Balance")
                            .font(.headline)
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.netBalance))
                            .font(.headline)
                            .foregroundColor(viewModel.netBalance >= 0 ? .green : .red)
                    }
                    
                    HStack {
                        Text("Savings Rate")
                            .font(.headline)
                        Spacer()
                        Text(viewModel.formatPercentage(viewModel.savingsRate))
                            .font(.headline)
                            .foregroundColor(viewModel.savingsRate >= 0 ? .green : .red)
                    }
                } header: {
                    Text("Summary")
                }
                
                // Category Breakdown
                if !viewModel.categoryBreakdown.isEmpty {
                    Section {
                        ForEach(viewModel.categoryBreakdown, id: \.category) { breakdown in
                            HStack {
                                Text(breakdown.category)
                                Spacer()
                                Text(viewModel.formatCurrency(breakdown.amount))
                                Text("(\(viewModel.formatPercentage(breakdown.percentage)))")
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Category Breakdown")
                    }
                }
            }
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        focusedField = nil
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showingAddEntrySheet = true }) {
                        Image(systemName: "plus.circle")
                    }
                }
            }
            .sheet(isPresented: $showingMonthPicker) {
                NavigationView {
                    VStack {
                        MonthYearPicker(selectedDate: $tempMonth)
                        Spacer()
                    }
                    .navigationTitle("Select Month")
                    .navigationBarItems(trailing: Button("Done") {
                        viewModel.updateMonth(tempMonth)
                        showingMonthPicker = false
                    })
                }
            }
            .sheet(isPresented: $viewModel.showingAddEntrySheet) {
                AddBudgetEntrySheet(viewModel: viewModel)
            }
        }
    }
}

struct BudgetEntryRow: View {
    let entry: BudgetEntry
    @ObservedObject var viewModel: BudgetViewModel
    @State private var showingEditSheet = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(entry.entryDescription)
                    .font(.headline)
                if let notes = entry.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(viewModel.formatCurrency(entry.amount))
                .foregroundColor(entry.isIncome ? .green : .red)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingEditSheet = true
        }
        .sheet(isPresented: $showingEditSheet) {
            EditBudgetEntrySheet(entry: entry, viewModel: viewModel)
        }
    }
}

struct AddBudgetEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BudgetViewModel
    @FocusState private var focusedField: BudgetView.Field?
    
    @State private var entryDescription = ""
    @State private var amount = 0.0
    @State private var category = ""
    @State private var isIncome = false
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Description", text: $entryDescription)
                    TextField("Amount", value: $amount, format: .currency(code: "SAR"))
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                    TextField("Category", text: $category)
                    Toggle("Is Income", isOn: $isIncome)
                    TextField("Notes (Optional)", text: $notes)
                        .focused($focusedField, equals: .notes)
                } header: {
                    Text("Entry Details")
                }
            }
            .navigationTitle("Add Entry")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    viewModel.addEntry(
                        entryDescription: entryDescription,
                        amount: amount,
                        category: category,
                        isIncome: isIncome,
                        notes: notes.isEmpty ? nil : notes
                    )
                    dismiss()
                }
                .disabled(entryDescription.isEmpty || amount <= 0 || category.isEmpty)
            )
        }
    }
}

struct EditBudgetEntrySheet: View {
    let entry: BudgetEntry
    @ObservedObject var viewModel: BudgetViewModel
    @Environment(\.presentationMode) private var presentationMode
    @FocusState private var focusedField: BudgetView.Field?
    
    @State private var entryDescription: String
    @State private var amount: Double
    @State private var category: String
    @State private var isIncome: Bool
    @State private var notes: String
    
    init(entry: BudgetEntry, viewModel: BudgetViewModel) {
        self.entry = entry
        self.viewModel = viewModel
        _entryDescription = State(initialValue: entry.entryDescription)
        _amount = State(initialValue: entry.amount)
        _category = State(initialValue: entry.category.rawValue)
        _isIncome = State(initialValue: entry.isIncome)
        _notes = State(initialValue: entry.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Description", text: $entryDescription)
                    TextField("Amount", value: $amount, format: .currency(code: "SAR"))
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                    TextField("Category", text: $category)
                    Toggle("Is Income", isOn: $isIncome)
                    TextField("Notes (Optional)", text: $notes)
                        .focused($focusedField, equals: .notes)
                } header: {
                    Text("Entry Details")
                }
                
                Section {
                    Button("Delete Entry", role: .destructive) {
                        viewModel.deleteEntry(entry)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    viewModel.updateEntry(
                        entry,
                        entryDescription: entryDescription,
                        amount: amount,
                        category: category,
                        isIncome: isIncome,
                        notes: notes.isEmpty ? nil : notes
                    )
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(entryDescription.isEmpty || amount <= 0 || category.isEmpty)
            )
        }
    }
}
