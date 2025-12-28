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
                Section(header: HStack {
                    Image(systemName: "calendar")
                    Text("Month")
                }) {
                    Button(action: {
                        // Add haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        tempMonth = viewModel.selectedMonth
                        showingMonthPicker = true
                    }) {
                        HStack {
                            Text("Select Month")
                            Spacer()
                            Text(viewModel.formatMonth(viewModel.selectedMonth))
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityLabel("Select Month")
                    .accessibilityHint("Tap to choose a different month")
                }
                
                // Income Section
                Section(header: HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.green)
                    Text("Income")
                }) {
                    ForEach(viewModel.entriesForMonth.filter { $0.isIncome }) { entry in
                        BudgetEntryRow(entry: entry, viewModel: viewModel)
                    }
                    
                    HStack {
                        Image(systemName: "sum")
                            .foregroundColor(.green)
                        Text("Total Income")
                            .bold()
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.totalIncome))
                            .bold()
                            .foregroundColor(.green)
                    }
                    .frame(minHeight: 44)
                }
                
                // Expenses Section
                Section(header: HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.red)
                    Text("Expenses")
                }) {
                    ForEach(viewModel.entriesForMonth.filter { !$0.isIncome }) { entry in
                        BudgetEntryRow(entry: entry, viewModel: viewModel)
                    }
                    
                    HStack {
                        Image(systemName: "sum")
                            .foregroundColor(.red)
                        Text("Total Expenses")
                            .bold()
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.totalExpenses))
                            .bold()
                            .foregroundColor(.red)
                    }
                    .frame(minHeight: 44)
                }
                
                // Summary Section
                Section(header: HStack {
                    Image(systemName: "chart.bar.fill")
                    Text("Summary")
                }) {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(viewModel.netBalance >= 0 ? .green : .red)
                        Text("Net Balance")
                            .font(.headline)
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.netBalance))
                            .font(.headline)
                            .foregroundColor(viewModel.netBalance >= 0 ? .green : .red)
                    }
                    .frame(minHeight: 44)
                    
                    HStack {
                        Image(systemName: "percent")
                            .foregroundColor(viewModel.savingsRate >= 0 ? .green : .red)
                        Text("Savings Rate")
                            .font(.headline)
                        Spacer()
                        Text(viewModel.formatPercentage(viewModel.savingsRate))
                            .font(.headline)
                            .foregroundColor(viewModel.savingsRate >= 0 ? .green : .red)
                    }
                    .frame(minHeight: 44)
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
            .listStyle(.insetGrouped)
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        focusedField = nil
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Add haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        viewModel.showingAddEntrySheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel("Add Budget Entry")
                    .accessibilityHint("Tap to add a new income or expense entry")
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
        Button(action: {
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            showingEditSheet = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: entry.isIncome ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .foregroundColor(entry.isIncome ? .green : .red)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.entryDescription)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if let notes = entry.notes {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(viewModel.formatCurrency(entry.amount))
                    .foregroundColor(entry.isIncome ? .green : .red)
                    .font(.headline)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.entryDescription), \(viewModel.formatCurrency(entry.amount))")
        .accessibilityHint("Tap to edit this budget entry")
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
