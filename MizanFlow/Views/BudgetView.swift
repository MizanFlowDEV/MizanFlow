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
                        .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                    Text("Month")
                        .font(DesignTokens.Typography.sectionTitle)
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
                                .font(DesignTokens.Typography.body)
                            Spacer()
                            Text(viewModel.formatMonth(viewModel.selectedMonth))
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(DesignTokens.Color.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: DesignTokens.Icon.small, weight: DesignTokens.Icon.weight))
                                .foregroundColor(DesignTokens.Color.textSecondary)
                        }
                        .frame(minHeight: DesignTokens.Calendar.minCellSize)
                    }
                    .accessibilityLabel("Select Month")
                    .accessibilityHint("Tap to choose a different month")
                }
                
                // Income Section
                Section(header: HStack {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(DesignTokens.Color.success)
                        .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                    Text("Income")
                        .font(DesignTokens.Typography.sectionTitle)
                }) {
                    ForEach(viewModel.entriesForMonth.filter { $0.isIncome }) { entry in
                        BudgetEntryRow(entry: entry, viewModel: viewModel)
                    }
                    
                    HStack {
                        Image(systemName: "sum")
                            .foregroundColor(DesignTokens.Color.success)
                            .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                        Text("Total Income")
                            .font(DesignTokens.Typography.sectionTitle)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.totalIncome))
                            .font(DesignTokens.Typography.sectionTitle)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignTokens.Color.success)
                    }
                    .frame(minHeight: DesignTokens.Calendar.minCellSize)
                }
                
                // Expenses Section
                Section(header: HStack {
                    Image(systemName: "arrow.up.circle")
                        .foregroundColor(DesignTokens.Color.error)
                        .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                    Text("Expenses")
                        .font(DesignTokens.Typography.sectionTitle)
                }) {
                    ForEach(viewModel.entriesForMonth.filter { !$0.isIncome }) { entry in
                        BudgetEntryRow(entry: entry, viewModel: viewModel)
                    }
                    
                    HStack {
                        Image(systemName: "sum")
                            .foregroundColor(DesignTokens.Color.error)
                            .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                        Text("Total Expenses")
                            .font(DesignTokens.Typography.sectionTitle)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.totalExpenses))
                            .font(DesignTokens.Typography.sectionTitle)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignTokens.Color.error)
                    }
                    .frame(minHeight: DesignTokens.Calendar.minCellSize)
                }
                
                // Summary Section
                Section(header: HStack {
                    Image(systemName: "chart.bar")
                        .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                    Text("Summary")
                        .font(DesignTokens.Typography.sectionTitle)
                }) {
                    HStack {
                        Image(systemName: "dollarsign.circle")
                            .foregroundColor(viewModel.netBalance >= 0 ? DesignTokens.Color.success : DesignTokens.Color.error)
                            .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                        Text("Net Balance")
                            .font(DesignTokens.Typography.sectionTitle)
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.netBalance))
                            .font(DesignTokens.Typography.sectionTitle)
                            .foregroundColor(viewModel.netBalance >= 0 ? DesignTokens.Color.success : DesignTokens.Color.error)
                    }
                    .frame(minHeight: DesignTokens.Calendar.minCellSize)
                    
                    HStack {
                        Image(systemName: "percent")
                            .foregroundColor(viewModel.savingsRate >= 0 ? DesignTokens.Color.success : DesignTokens.Color.error)
                            .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                        Text("Savings Rate")
                            .font(DesignTokens.Typography.sectionTitle)
                        Spacer()
                        Text(viewModel.formatPercentage(viewModel.savingsRate))
                            .font(DesignTokens.Typography.sectionTitle)
                            .foregroundColor(viewModel.savingsRate >= 0 ? DesignTokens.Color.success : DesignTokens.Color.error)
                    }
                    .frame(minHeight: DesignTokens.Calendar.minCellSize)
                }
                
                // Category Breakdown
                if !viewModel.categoryBreakdown.isEmpty {
                    Section {
                        ForEach(viewModel.categoryBreakdown, id: \.category) { breakdown in
                            HStack {
                                Text(breakdown.category)
                                    .font(DesignTokens.Typography.body)
                                Spacer()
                                Text(viewModel.formatCurrency(breakdown.amount))
                                    .font(DesignTokens.Typography.body)
                                Text("(\(viewModel.formatPercentage(breakdown.percentage)))")
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundColor(DesignTokens.Color.textSecondary)
                            }
                        }
                    } header: {
                        Text("Category Breakdown")
                            .font(DesignTokens.Typography.sectionTitle)
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
                        Image(systemName: "plus.circle")
                            .font(.system(size: DesignTokens.Icon.large, weight: DesignTokens.Icon.weight))
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
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: entry.isIncome ? "arrow.down.circle" : "arrow.up.circle")
                    .foregroundColor(entry.isIncome ? DesignTokens.Color.success : DesignTokens.Color.error)
                    .font(.system(size: DesignTokens.Icon.large, weight: DesignTokens.Icon.weight))
                
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(entry.entryDescription)
                        .font(DesignTokens.Typography.sectionTitle)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    if let notes = entry.notes {
                        Text(notes)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Color.textSecondary)
                    }
                }
                
                Spacer()
                
                Text(viewModel.formatCurrency(entry.amount))
                    .foregroundColor(entry.isIncome ? DesignTokens.Color.success : DesignTokens.Color.error)
                    .font(DesignTokens.Typography.sectionTitle)
            }
            .frame(minHeight: DesignTokens.Calendar.minCellSize)
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
