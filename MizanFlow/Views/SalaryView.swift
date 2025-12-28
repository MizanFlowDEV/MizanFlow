import SwiftUI

/// SalaryView displays and manages salary calculations with Apple Design Guidelines compliance
struct SalaryView: View {
    @StateObject private var viewModel = SalaryViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingMonthPicker = false
    @State private var tempMonth = Date()
    @FocusState private var focusedField: Field?
    
    // Track previous values for threshold detection
    @State private var previousHomeLoanPercentage: Double = 0
    @State private var previousESPPPercentage: Double = 0
    
    enum Field {
        case baseSalary
    }
    
    // MARK: - Constants (Apple Design Guidelines)
    private let minimumHitTarget: CGFloat = 44
    private let sectionSpacing: CGFloat = 16
    private let horizontalPadding: CGFloat = 16
    
    // MARK: - Helper Functions
    
    /// Checks if a threshold was crossed for haptic feedback
    private func didCrossThreshold(current: Double, previous: Double, threshold: Double) -> Bool {
        let previousBucket = Int(previous / threshold)
        let currentBucket = Int(current / threshold)
        return previousBucket != currentBucket
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: sectionSpacing) {
                    // Base Salary Section
                    baseSalarySection
                    
                    // Month Selector
                    monthSelectorSection
                    
                    // Allowances Section
                    allowancesSection
                    
                    // Overtime Section
                    overtimeSection
                    
                    // Deductions Section
                    deductionsSection
                    
                    // Additional Income Section
                    if !viewModel.salaryBreakdown.additionalIncome.isEmpty {
                        additionalIncomeSection
                    }
                    
                    // Summary Section
                    summarySection
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, sectionSpacing)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Salary")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                        .font(.body)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { viewModel.showingAddIncomeSheet = true }) {
                            Label("Add Income", systemImage: "plus.circle")
                        }
                        Button(action: { viewModel.showingAddDeductionSheet = true }) {
                            Label("Add Deduction", systemImage: "minus.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                    }
                    .accessibilityLabel("More options")
                }
            }
            .sheet(isPresented: $showingMonthPicker) {
                monthPickerSheet
            }
            .sheet(isPresented: $viewModel.showingAddIncomeSheet) {
                AddIncomeSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingAddDeductionSheet) {
                AddDeductionSheet(viewModel: viewModel)
            }
        }
    }
    
    // MARK: - Section Views
    
    private var baseSalarySection: some View {
        SectionCard(title: "Base Salary", icon: "dollarsign.circle.fill", iconColor: .green) {
            HStack {
                Text("Monthly Base")
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
                TextField("Enter base salary", value: $viewModel.salaryBreakdown.baseSalary, format: .currency(code: "SAR"))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .baseSalary)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .frame(minHeight: minimumHitTarget)
            .accessibilityLabel("Monthly Base Salary")
            .accessibilityHint("Enter your monthly base salary amount")
        }
    }
    
    private var monthSelectorSection: some View {
        SectionCard(title: "Month", icon: "calendar", iconColor: .blue) {
            Button(action: {
                HapticFeedback.selection()
                tempMonth = viewModel.selectedMonth
                showingMonthPicker = true
            }) {
                HStack {
                    Text("Select Month")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(viewModel.formatMonth(viewModel.selectedMonth))
                        .font(.body)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(minHeight: minimumHitTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select Month")
            .accessibilityHint("Tap to choose a different month")
        }
    }
    
    private var allowancesSection: some View {
        SectionCard(title: "Allowances", icon: "plus.circle.fill", iconColor: .blue) {
            VStack(spacing: 12) {
                AllowanceRow(
                    icon: "location.fill",
                    title: "Remote Location",
                    amount: viewModel.formatCurrency(viewModel.remoteAllowance)
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("Special Operations")
                            .font(.body)
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.specialOperationsAllowance))
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .frame(minHeight: minimumHitTarget)
                    
                    Picker("Percentage", selection: Binding(
                        get: { viewModel.salaryBreakdown.specialOperationsPercentage },
                        set: { viewModel.updateSpecialOperationsPercentage($0) }
                    )) {
                        Text("5%").tag(5.0)
                        Text("7%").tag(7.0)
                        Text("10%").tag(10.0)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Special Operations Percentage")
                }
                
                AllowanceRow(
                    icon: "car.fill",
                    title: "Transportation",
                    amount: viewModel.formatCurrency(viewModel.transportationAllowance)
                )
                
                Divider()
                
                HStack {
                    Image(systemName: "sum")
                        .font(.body)
                        .foregroundColor(.blue)
                    Text("Total Allowances")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(viewModel.formatCurrency(viewModel.totalAllowances))
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                .frame(minHeight: minimumHitTarget)
            }
        }
    }
    
    private var overtimeSection: some View {
        SectionCard(title: "Overtime", icon: "clock.fill", iconColor: .orange) {
            VStack(spacing: 12) {
                OvertimeRow(
                    icon: "clock.badge.fill",
                    title: "Overtime Hours",
                    value: String(format: "%.1f", viewModel.salaryBreakdown.overtimeHours),
                    isAmount: false
                )
                
                OvertimeRow(
                    icon: "dollarsign.circle.fill",
                    title: "Overtime Pay",
                    value: viewModel.formatCurrency(viewModel.overtimePay),
                    isAmount: true
                )
                
                OvertimeRow(
                    icon: "clock.arrow.circlepath",
                    title: "ADL Hours",
                    value: String(format: "%.1f", viewModel.salaryBreakdown.adlHours),
                    isAmount: false
                )
                
                OvertimeRow(
                    icon: "dollarsign.circle.fill",
                    title: "ADL Pay",
                    value: viewModel.formatCurrency(viewModel.adlPay),
                    isAmount: true
                )
            }
        }
    }
    
    private var deductionsSection: some View {
        SectionCard(title: "Deductions", icon: "minus.circle.fill", iconColor: .red) {
            VStack(spacing: 16) {
                // Home Loan with Slider
                DeductionSliderRow(
                    icon: "house.fill",
                    title: "Home Loan",
                    amount: viewModel.formatCurrency(viewModel.homeLoanDeduction),
                    percentage: viewModel.salaryBreakdown.homeLoanPercentage,
                    range: 0...50,
                    step: 1,
                    previousValue: $previousHomeLoanPercentage,
                    onValueChange: { newValue in
                        viewModel.updateDeductionPercentagesSilently(
                            homeLoan: newValue,
                            espp: viewModel.salaryBreakdown.esppPercentage
                        )
                        if didCrossThreshold(current: newValue, previous: previousHomeLoanPercentage, threshold: 10.0) {
                            HapticFeedback.selection()
                        }
                        previousHomeLoanPercentage = newValue
                    }
                )
                .onAppear {
                    previousHomeLoanPercentage = viewModel.salaryBreakdown.homeLoanPercentage
                }
                
                // ESPP with Slider
                DeductionSliderRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "ESPP",
                    amount: viewModel.formatCurrency(viewModel.esppDeduction),
                    percentage: viewModel.salaryBreakdown.esppPercentage,
                    range: 0...10,
                    step: 1,
                    previousValue: $previousESPPPercentage,
                    onValueChange: { newValue in
                        viewModel.updateDeductionPercentagesSilently(
                            homeLoan: viewModel.salaryBreakdown.homeLoanPercentage,
                            espp: newValue
                        )
                        if didCrossThreshold(current: newValue, previous: previousESPPPercentage, threshold: 1.0) {
                            HapticFeedback.selection()
                        }
                        previousESPPPercentage = newValue
                    }
                )
                .onAppear {
                    previousESPPPercentage = viewModel.salaryBreakdown.esppPercentage
                }
                
                DeductionRow(
                    icon: "shield.fill",
                    title: "GOSI",
                    amount: viewModel.formatCurrency(viewModel.gosiDeduction)
                )
                
                DeductionRow(
                    icon: "heart.fill",
                    title: "SANID",
                    amount: viewModel.formatCurrency(viewModel.sanidDeduction)
                )
                
                // Custom Deductions
                if !viewModel.salaryBreakdown.customDeductions.isEmpty {
                    ForEach(viewModel.salaryBreakdown.customDeductions) { deduction in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "minus.circle")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .frame(width: 20)
                                Text(deduction.entryDescription)
                                    .font(.headline)
                                Spacer()
                                Text(viewModel.formatCurrency(deduction.amount))
                                    .font(.body)
                                    .foregroundColor(.red)
                            }
                            if let notes = deduction.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 28)
                            }
                        }
                        .frame(minHeight: minimumHitTarget)
                    }
                }
                
                Divider()
                
                HStack {
                    Image(systemName: "sum")
                        .font(.body)
                        .foregroundColor(.red)
                    Text("Total Deductions")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(viewModel.formatCurrency(viewModel.totalDeductions))
                        .font(.headline)
                        .foregroundColor(.red)
                }
                .frame(minHeight: minimumHitTarget)
            }
        }
    }
    
    private var additionalIncomeSection: some View {
        SectionCard(title: "Additional Income", icon: "plus.circle.fill", iconColor: .green) {
            VStack(spacing: 12) {
                ForEach(viewModel.salaryBreakdown.additionalIncome) { income in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                                .frame(width: 20)
                            Text(income.entryDescription)
                                .font(.headline)
                            Spacer()
                            Text(viewModel.formatCurrency(income.amount))
                                .font(.body)
                                .foregroundColor(.green)
                        }
                        if let notes = income.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 28)
                        }
                    }
                    .frame(minHeight: minimumHitTarget)
                }
            }
        }
    }
    
    private var summarySection: some View {
        SectionCard(title: "Summary", icon: "chart.bar.fill", iconColor: .blue) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.body)
                        .foregroundColor(.blue)
                    Text("Total Compensation")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(viewModel.formatCurrency(viewModel.totalCompensation))
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                .frame(minHeight: minimumHitTarget)
                
                Divider()
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundColor(.green)
                    Text("Net Pay")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(viewModel.formatCurrency(viewModel.netPay))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .frame(minHeight: minimumHitTarget)
            }
        }
    }
    
    // MARK: - Sheet Views
    
    private var monthPickerSheet: some View {
        NavigationView {
            VStack {
                MonthYearPicker(selectedDate: $tempMonth)
                Spacer()
            }
            .navigationTitle("Select Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingMonthPicker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.updateMonth(tempMonth)
                        showingMonthPicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Reusable Components

/// Section card container following Apple Design Guidelines
struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: Content
    
    init(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 4)
            
            content
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

/// Allowance row component
struct AllowanceRow: View {
    let icon: String
    let title: String
    let amount: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
            Text(amount)
                .font(.body)
                .foregroundColor(.primary)
        }
        .frame(minHeight: 44)
    }
}

/// Overtime row component
struct OvertimeRow: View {
    let icon: String
    let title: String
    let value: String
    let isAmount: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.orange)
                .frame(width: 20)
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(isAmount ? .orange : .secondary)
        }
        .frame(minHeight: 44)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityHint(isAmount ? "Amount" : "Hours")
    }
}

/// Deduction row component
struct DeductionRow: View {
    let icon: String
    let title: String
    let amount: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.red)
                .frame(width: 20)
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
            Text(amount)
                .font(.body)
                .foregroundColor(.red)
        }
        .frame(minHeight: 44)
    }
}

/// Deduction slider row component
struct DeductionSliderRow: View {
    let icon: String
    let title: String
    let amount: String
    let percentage: Double
    let range: ClosedRange<Double>
    let step: Double
    @Binding var previousValue: Double
    let onValueChange: (Double) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(width: 20)
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
                Text(amount)
                    .font(.headline)
                    .foregroundColor(.red)
            }
            .frame(minHeight: 44)
            
            HStack(spacing: 12) {
                Text("\(Int(percentage))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
                    .accessibilityHidden(true)
                
                Slider(
                    value: Binding(
                        get: { percentage },
                        set: onValueChange
                    ),
                    in: range,
                    step: step
                )
                .accessibilityLabel("\(title) percentage")
                .accessibilityValue("\(Int(percentage)) percent")
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sheet Views

struct AddIncomeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SalaryViewModel
    @State private var amount = 0.0
    @State private var entryDescription = ""
    @State private var notes = ""
    @FocusState private var focusedField: Field?
    
    enum Field {
        case description, amount, notes
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Income Details")) {
                    TextField("Description", text: $entryDescription)
                        .focused($focusedField, equals: .description)
                        .submitLabel(.next)
                    TextField("Amount", value: $amount, format: .currency(code: "SAR"))
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                        .submitLabel(.next)
                    TextField("Notes (Optional)", text: $notes)
                        .focused($focusedField, equals: .notes)
                        .submitLabel(.done)
                }
            }
            .navigationTitle("Add Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addAdditionalIncome(
                            description: entryDescription,
                            amount: amount,
                            notes: notes.isEmpty ? nil : notes
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(entryDescription.isEmpty || amount <= 0)
                }
            }
        }
    }
}

struct AddDeductionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SalaryViewModel
    @State private var amount = 0.0
    @State private var entryDescription = ""
    @State private var notes = ""
    @FocusState private var focusedField: Field?
    
    enum Field {
        case description, amount, notes
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Deduction Details")) {
                    TextField("Description", text: $entryDescription)
                        .focused($focusedField, equals: .description)
                        .submitLabel(.next)
                    TextField("Amount", value: $amount, format: .currency(code: "SAR"))
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                        .submitLabel(.next)
                    TextField("Notes (Optional)", text: $notes)
                        .focused($focusedField, equals: .notes)
                        .submitLabel(.done)
                }
            }
            .navigationTitle("Add Deduction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addCustomDeduction(
                            description: entryDescription,
                            amount: amount,
                            notes: notes.isEmpty ? nil : notes
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(entryDescription.isEmpty || amount <= 0)
                }
            }
        }
    }
}
