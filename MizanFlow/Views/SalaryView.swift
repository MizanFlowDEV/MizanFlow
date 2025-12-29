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
    
    // MARK: - Constants (Design Tokens)
    private let minimumHitTarget: CGFloat = DesignTokens.Calendar.minCellSize
    private let sectionSpacing: CGFloat = DesignTokens.Spacing.md
    private let horizontalPadding: CGFloat = DesignTokens.Spacing.md
    
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
                    
                    // Work Schedule Summary Section
                    if let summary = viewModel.workScheduleSummary {
                        workScheduleSummarySection(summary: summary)
                    }
                    
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
            .onAppear {
                AppLogger.ui.debug("SalaryView appeared - reloading schedule: selectedMonth=\(viewModel.selectedMonth.formatted(date: .abbreviated, time: .omitted))")
                viewModel.reloadSchedule()
            }
        }
    }
    
    // MARK: - Section Views
    
    private var baseSalarySection: some View {
        SectionCard(title: "Base Salary", icon: "dollarsign.circle", iconColor: DesignTokens.Color.success) {
            HStack {
                Text("Monthly Base")
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Color.textPrimary)
                Spacer()
                TextField("Enter base salary", value: $viewModel.salaryBreakdown.baseSalary, format: .currency(code: "SAR"))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .baseSalary)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Color.textPrimary)
            }
            .frame(minHeight: minimumHitTarget)
            .accessibilityLabel("Monthly Base Salary")
            .accessibilityHint("Enter your monthly base salary amount")
        }
    }
    
    private var monthSelectorSection: some View {
        SectionCard(title: "Month", icon: "calendar", iconColor: DesignTokens.Color.primary) {
            Button(action: {
                HapticFeedback.selection()
                tempMonth = viewModel.selectedMonth
                showingMonthPicker = true
            }) {
                HStack {
                    Text("Select Month")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Spacer()
                    Text(viewModel.formatMonth(viewModel.selectedMonth))
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Color.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: DesignTokens.Icon.small, weight: DesignTokens.Icon.weight))
                        .foregroundColor(DesignTokens.Color.textSecondary)
                }
                .frame(minHeight: minimumHitTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select Month")
            .accessibilityHint("Tap to choose a different month")
        }
    }
    
    private var allowancesSection: some View {
        SectionCard(title: "Allowances", icon: "plus.circle", iconColor: DesignTokens.Color.primary) {
            VStack(spacing: DesignTokens.Spacing.md) {
                AllowanceRow(
                    icon: "location",
                    title: "Remote Location",
                    amount: viewModel.formatCurrency(viewModel.remoteAllowance)
                )
                
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Image(systemName: "star")
                            .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                            .foregroundColor(DesignTokens.Color.primary)
                            .frame(width: DesignTokens.Icon.large)
                        Text("Special Operations")
                            .font(DesignTokens.Typography.body)
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.specialOperationsAllowance))
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Color.textPrimary)
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
                
                // Housing Allowance - Only shown in December (annual payment)
                if Calendar.current.component(.month, from: viewModel.selectedMonth) == 12 {
                    AllowanceRow(
                        icon: "house.fill",
                        title: "Housing",
                        amount: viewModel.formatCurrency(viewModel.housingAllowance)
                    )
                }
                
                AllowanceRow(
                    icon: "car",
                    title: "Transportation",
                    amount: viewModel.formatCurrency(viewModel.transportationAllowance)
                )
                
                Divider()
                
                HStack {
                    Image(systemName: "sum")
                        .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                        .foregroundColor(DesignTokens.Color.primary)
                    Text("Total Allowances")
                        .font(DesignTokens.Typography.sectionTitle)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Spacer()
                    Text(viewModel.formatCurrency(viewModel.totalAllowances))
                        .font(DesignTokens.Typography.sectionTitle)
                        .foregroundColor(DesignTokens.Color.primary)
                }
                .frame(minHeight: minimumHitTarget)
            }
        }
    }
    
    private var overtimeSection: some View {
        SectionCard(title: "Overtime", icon: "clock", iconColor: DesignTokens.Color.warning) {
            VStack(spacing: DesignTokens.Spacing.md) {
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
        SectionCard(title: "Deductions", icon: "minus.circle", iconColor: DesignTokens.Color.error) {
            VStack(spacing: DesignTokens.Spacing.md) {
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
                    icon: "shield",
                    title: "GOSI",
                    amount: viewModel.formatCurrency(viewModel.gosiDeduction)
                )
                
                DeductionRow(
                    icon: "heart",
                    title: "SANID",
                    amount: viewModel.formatCurrency(viewModel.sanidDeduction)
                )
                
                // Custom Deductions
                if !viewModel.salaryBreakdown.customDeductions.isEmpty {
                    ForEach(viewModel.salaryBreakdown.customDeductions) { deduction in
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            HStack {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                                    .foregroundColor(DesignTokens.Color.error)
                                    .frame(width: DesignTokens.Icon.large)
                                Text(deduction.entryDescription)
                                    .font(DesignTokens.Typography.sectionTitle)
                                Spacer()
                                Text(viewModel.formatCurrency(deduction.amount))
                                    .font(DesignTokens.Typography.body)
                                    .foregroundColor(DesignTokens.Color.error)
                            }
                            if let notes = deduction.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundColor(DesignTokens.Color.textSecondary)
                                    .padding(.leading, DesignTokens.Spacing.lg)
                            }
                        }
                        .frame(minHeight: minimumHitTarget)
                    }
                }
                
                Divider()
                
                HStack {
                    Image(systemName: "sum")
                        .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                        .foregroundColor(DesignTokens.Color.error)
                    Text("Total Deductions")
                        .font(DesignTokens.Typography.sectionTitle)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Spacer()
                    Text(viewModel.formatCurrency(viewModel.totalDeductions))
                        .font(DesignTokens.Typography.sectionTitle)
                        .foregroundColor(DesignTokens.Color.error)
                }
                .frame(minHeight: minimumHitTarget)
            }
        }
    }
    
    private var additionalIncomeSection: some View {
        SectionCard(title: "Additional Income", icon: "plus.circle", iconColor: DesignTokens.Color.success) {
            VStack(spacing: DesignTokens.Spacing.md) {
                ForEach(viewModel.salaryBreakdown.additionalIncome) { income in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                                .foregroundColor(DesignTokens.Color.success)
                                .frame(width: DesignTokens.Icon.large)
                            Text(income.entryDescription)
                                .font(DesignTokens.Typography.sectionTitle)
                            Spacer()
                            Text(viewModel.formatCurrency(income.amount))
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(DesignTokens.Color.success)
                        }
                        if let notes = income.notes, !notes.isEmpty {
                            Text(notes)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Color.textSecondary)
                                .padding(.leading, DesignTokens.Spacing.lg)
                        }
                    }
                    .frame(minHeight: minimumHitTarget)
                }
            }
        }
    }
    
    private func workScheduleSummarySection(summary: SalaryBreakdown.WorkScheduleSummary) -> some View {
        SectionCard(title: "Work Schedule Summary", icon: "calendar.badge.clock", iconColor: DesignTokens.Color.primary) {
            VStack(spacing: DesignTokens.Spacing.md) {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                        .foregroundColor(DesignTokens.Color.primary)
                    Text("Paid Hours")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Spacer()
                    Text(String(format: "%.1f", summary.paidHours))
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                }
                .frame(minHeight: minimumHitTarget)
                
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                        .foregroundColor(DesignTokens.Color.primary)
                    Text("Paid Leave Hours")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Spacer()
                    Text(String(format: "%.1f", summary.paidLeaveHours))
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                }
                .frame(minHeight: minimumHitTarget)
                
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                        .foregroundColor(DesignTokens.Color.primary)
                    Text("Straight Time Hours")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Spacer()
                    Text(String(format: "%.1f", summary.straightTimeHours))
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                }
                .frame(minHeight: minimumHitTarget)
                
                HStack {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                        .foregroundColor(DesignTokens.Color.warning)
                    Text("Premium Hours")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Spacer()
                    Text(String(format: "%.1f", summary.premiumHours))
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Color.warning)
                }
                .frame(minHeight: minimumHitTarget)
            }
        }
    }
    
    private var summarySection: some View {
        SectionCard(title: "Summary", icon: "chart.bar", iconColor: DesignTokens.Color.primary) {
            VStack(spacing: DesignTokens.Spacing.md) {
                HStack {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                        .foregroundColor(DesignTokens.Color.primary)
                    Text("Total Compensation")
                        .font(DesignTokens.Typography.sectionTitle)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Spacer()
                    Text(viewModel.formatCurrency(viewModel.totalCompensation))
                        .font(DesignTokens.Typography.sectionTitle)
                        .foregroundColor(DesignTokens.Color.primary)
                }
                .frame(minHeight: minimumHitTarget)
                
                Divider()
                
                HStack {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                        .foregroundColor(DesignTokens.Color.success)
                    Text("Net Pay")
                        .font(DesignTokens.Typography.screenTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignTokens.Color.textPrimary)
                    Spacer()
                    Text(viewModel.formatCurrency(viewModel.netPay))
                        .font(DesignTokens.Typography.screenTitle)
                        .fontWeight(.bold)
                        .foregroundColor(DesignTokens.Color.success)
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

/// Section card container following Design System
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundColor(DesignTokens.Color.textPrimary)
            }
            .padding(.bottom, DesignTokens.Spacing.xs)
            
            content
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Color.surface)
        .cornerRadius(DesignTokens.CornerRadius.large)
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
                .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                .foregroundColor(DesignTokens.Color.primary)
                .frame(width: DesignTokens.Icon.large)
            Text(title)
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Color.textPrimary)
            Spacer()
            Text(amount)
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Color.textPrimary)
        }
        .frame(minHeight: DesignTokens.Calendar.minCellSize)
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
                .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                .foregroundColor(DesignTokens.Color.warning)
                .frame(width: DesignTokens.Icon.large)
            Text(title)
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Color.textPrimary)
            Spacer()
            Text(value)
                .font(DesignTokens.Typography.body)
                .foregroundColor(isAmount ? DesignTokens.Color.warning : DesignTokens.Color.textSecondary)
        }
        .frame(minHeight: DesignTokens.Calendar.minCellSize)
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
                .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                .foregroundColor(DesignTokens.Color.error)
                .frame(width: DesignTokens.Icon.large)
            Text(title)
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Color.textPrimary)
            Spacer()
            Text(amount)
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Color.error)
        }
        .frame(minHeight: DesignTokens.Calendar.minCellSize)
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                    .foregroundColor(DesignTokens.Color.error)
                    .frame(width: DesignTokens.Icon.large)
                Text(title)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Color.textPrimary)
                Spacer()
                Text(amount)
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundColor(DesignTokens.Color.error)
            }
            .frame(minHeight: DesignTokens.Calendar.minCellSize)
            
            HStack(spacing: DesignTokens.Spacing.md) {
                Text("\(Int(percentage))%")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Color.textSecondary)
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
        .padding(.vertical, DesignTokens.Spacing.xs)
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
