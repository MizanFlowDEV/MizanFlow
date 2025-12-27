import SwiftUI

struct SalaryView: View {
    @StateObject private var viewModel = SalaryViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingMonthPicker = false
    @State private var tempMonth = Date()
    @FocusState private var focusedField: Field?
    
    enum Field {
        case baseSalary
        case overtimeHours
        case adlHours
    }
    
    var body: some View {
        NavigationView {
            List {
                // Base Salary Section
                Section(header: Text("Base Salary")) {
                    HStack {
                        Text("Monthly Base")
                        Spacer()
                        TextField("Enter base salary", value: $viewModel.salaryBreakdown.baseSalary, format: .currency(code: "SAR"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .baseSalary)
                    }
                }
                
                // Month Selector
                Section(header: Text("Month")) {
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
                }
                
                // Allowances Section
                Section(header: Text("Allowances")) {
                    HStack {
                        Text("Remote Location")
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.remoteAllowance))
                    }
                    
                    HStack {
                        Text("Special Operations")
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.specialOperationsAllowance))
                    }
                    
                    HStack {
                        Text("Transportation")
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.transportationAllowance))
                    }
                    
                    HStack {
                        Text("Total Allowances")
                            .bold()
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.totalAllowances))
                            .bold()
                    }
                }
                
                // Overtime Section
                Section(header: Text("Overtime")) {
                    HStack {
                        Text("Overtime Hours")
                        Spacer()
                        TextField("Hours", value: $viewModel.salaryBreakdown.overtimeHours, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .overtimeHours)
                    }
                    
                    HStack {
                        Text("Overtime Pay")
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.overtimePay))
                    }
                    
                    HStack {
                        Text("ADL Hours")
                        Spacer()
                        TextField("Hours", value: $viewModel.salaryBreakdown.adlHours, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .adlHours)
                    }
                    
                    HStack {
                        Text("ADL Pay")
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.adlPay))
                    }
                }
                
                // Deductions Section
                Section(header: Text("Deductions")) {
                    HStack {
                        Text("Home Loan")
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.homeLoanDeduction))
                    }
                    
                    HStack {
                        Text("ESPP")
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.esppDeduction))
                    }
                    
                    HStack {
                        Text("GOSI")
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.gosiDeduction))
                    }
                    
                    HStack {
                        Text("SANID")
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.sanidDeduction))
                    }
                    
                    if !viewModel.salaryBreakdown.customDeductions.isEmpty {
                        ForEach(viewModel.salaryBreakdown.customDeductions) { deduction in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(deduction.entryDescription)
                                        .font(.headline)
                                    if let notes = deduction.notes {
                                        Text(notes)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text(viewModel.formatCurrency(deduction.amount))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    HStack {
                        Text("Total Deductions")
                            .bold()
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.totalDeductions))
                            .bold()
                    }
                }
                
                // Additional Income Section
                if !viewModel.salaryBreakdown.additionalIncome.isEmpty {
                    Section(header: Text("Additional Income")) {
                        ForEach(viewModel.salaryBreakdown.additionalIncome) { income in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(income.entryDescription)
                                        .font(.headline)
                                    if let notes = income.notes {
                                        Text(notes)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text(viewModel.formatCurrency(income.amount))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                // Summary Section
                Section(header: Text("Summary")) {
                    HStack {
                        Text("Total Compensation")
                            .bold()
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.totalCompensation))
                            .bold()
                    }
                    
                    HStack {
                        Text("Net Pay")
                            .font(.headline)
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.netPay))
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("Salary")
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        focusedField = nil
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { viewModel.showingAddIncomeSheet = true }) {
                            Label("Add Income", systemImage: "plus.circle")
                        }
                        
                        Button(action: { viewModel.showingAddDeductionSheet = true }) {
                            Label("Add Deduction", systemImage: "minus.circle")
                        }
                        
                        Button(action: { viewModel.showingEditPercentagesSheet = true }) {
                            Label("Edit Percentages", systemImage: "percent")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
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
            .sheet(isPresented: $viewModel.showingAddIncomeSheet) {
                AddIncomeSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingAddDeductionSheet) {
                AddDeductionSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingEditPercentagesSheet) {
                EditPercentagesSheet(viewModel: viewModel)
            }
        }
    }
}

struct AddIncomeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SalaryViewModel
    @State private var amount = 0.0
    @State private var entryDescription = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Income Details")) {
                    TextField("Description", text: $entryDescription)
                    TextField("Amount", value: $amount, format: .currency(code: "SAR"))
                        .keyboardType(.decimalPad)
                    TextField("Notes (Optional)", text: $notes)
                }
            }
            .navigationTitle("Add Income")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Add") {
                    viewModel.addAdditionalIncome(
                        description: entryDescription,
                        amount: amount,
                        notes: notes.isEmpty ? nil : notes
                    )
                    dismiss()
                }
                .disabled(entryDescription.isEmpty || amount <= 0)
            )
        }
    }
}

struct AddDeductionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SalaryViewModel
    @State private var amount = 0.0
    @State private var entryDescription = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Deduction Details")) {
                    TextField("Description", text: $entryDescription)
                    TextField("Amount", value: $amount, format: .currency(code: "SAR"))
                        .keyboardType(.decimalPad)
                    TextField("Notes (Optional)", text: $notes)
                }
            }
            .navigationTitle("Add Deduction")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Add") {
                    viewModel.addCustomDeduction(
                        description: entryDescription,
                        amount: amount,
                        notes: notes.isEmpty ? nil : notes
                    )
                    dismiss()
                }
                .disabled(entryDescription.isEmpty || amount <= 0)
            )
        }
    }
}

// EditPercentagesSheet with horizontal wheel pickers
struct EditPercentagesSheet: View {
    @ObservedObject var viewModel: SalaryViewModel
    @Environment(\.presentationMode) private var presentationMode
    
    @State private var homeLoanPercentage: Int
    @State private var esppPercentage: Int
    @State private var specialOperationsPercentage: Double
    @State private var isHomeLoanEnabled: Bool
    @State private var isESPPEnabled: Bool
    
    init(viewModel: SalaryViewModel) {
        self.viewModel = viewModel
        _homeLoanPercentage = State(initialValue: Int(viewModel.salaryBreakdown.homeLoanPercentage))
        _esppPercentage = State(initialValue: Int(viewModel.salaryBreakdown.esppPercentage))
        _specialOperationsPercentage = State(initialValue: viewModel.salaryBreakdown.specialOperationsPercentage)
        _isHomeLoanEnabled = State(initialValue: viewModel.salaryBreakdown.homeLoanPercentage > 0)
        _isESPPEnabled = State(initialValue: viewModel.salaryBreakdown.esppPercentage > 0)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Home Loan Deduction")) {
                    Toggle("Enable Home Loan", isOn: $isHomeLoanEnabled)
                    
                    if isHomeLoanEnabled {
                        VStack(alignment: .leading) {
                            Text("Percentage: \(homeLoanPercentage)%")
                                .font(.headline)
                            
                            Slider(value: Binding(
                                get: { Double(homeLoanPercentage) },
                                set: { homeLoanPercentage = Int($0) }
                            ), in: 25...50, step: 1)
                        }
                    }
                }
                
                Section(header: Text("ESPP Deduction")) {
                    Toggle("Enable ESPP", isOn: $isESPPEnabled)
                    
                    if isESPPEnabled {
                        VStack(alignment: .leading) {
                            Text("Percentage: \(esppPercentage)%")
                                .font(.headline)
                            
                            Slider(value: Binding(
                                get: { Double(esppPercentage) },
                                set: { esppPercentage = Int($0) }
                            ), in: 1...10, step: 1)
                        }
                    }
                }
                
                Section(header: Text("Special Operations")) {
                    Picker("Percentage", selection: $specialOperationsPercentage) {
                        Text("5%").tag(5.0)
                        Text("7%").tag(7.0)
                        Text("10%").tag(10.0)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Edit Percentages")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    viewModel.updateDeductionPercentages(
                        homeLoan: isHomeLoanEnabled ? Double(homeLoanPercentage) : 0,
                        espp: isESPPEnabled ? Double(esppPercentage) : 0
                    )
                    viewModel.updateSpecialOperationsPercentage(specialOperationsPercentage)
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
} 
