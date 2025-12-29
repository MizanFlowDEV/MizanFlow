import SwiftUI

struct DayDetailView: View {
    let date: Date
    let dayType: DayType
    let isOverride: Bool
    let notes: String?
    let hitchPosition: Int
    @ObservedObject var viewModel: WorkScheduleViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedType: DayType = .workday
    @State private var customNotes: String = ""
    @State private var showingOverrideConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Day Information")
                    .font(DesignTokens.Typography.sectionTitle)) {
                    HStack {
                        Text("Date:")
                            .font(DesignTokens.Typography.body)
                        Spacer()
                        Text(formattedDate)
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Color.textSecondary)
                    }
                    
                    HStack {
                        Text("Type:")
                            .font(DesignTokens.Typography.body)
                        Spacer()
                        Text(viewModel.getDayDescription(for: dayType))
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(getColorForDayType())
                    }
                    
                    if isOverride {
                        HStack {
                            Text("Manual Override:")
                                .font(DesignTokens.Typography.body)
                            Spacer()
                            Text("Yes")
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(DesignTokens.Color.error)
                        }
                    }
                    
                    HStack {
                        Text("Hitch Position:")
                            .font(DesignTokens.Typography.body)
                        Spacer()
                        Text(getHitchPositionDescription())
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(hitchPosition < 14 ? DesignTokens.Color.primary : DesignTokens.Color.textSecondary)
                    }
                    
                    if let overtime = viewModel.getOvertimeHours(for: date), overtime > 0 {
                        HStack {
                            Text("Overtime Hours:")
                                .font(DesignTokens.Typography.body)
                            Spacer()
                            Text("\(Int(overtime)) hrs")
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(DesignTokens.Color.success)
                        }
                    }
                    
                    if viewModel.hasIcon(for: date), let iconName = viewModel.getIconName(for: date) {
                        HStack {
                            Text("Special Mark:")
                                .font(DesignTokens.Typography.body)
                            Spacer()
                            Image(systemName: iconName)
                                .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                                .foregroundColor(DesignTokens.Color.textPrimary)
                        }
                    }
                }
                
                if let notes = notes, !notes.isEmpty {
                    Section(header: Text("Notes")
                        .font(DesignTokens.Typography.sectionTitle)) {
                        Text(notes)
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Color.textSecondary)
                    }
                }
                
                // Only show manual override options if not already overridden
                // or if user is viewing an overridden day
                Section(header: Text("Manual Override")
                    .font(DesignTokens.Typography.sectionTitle)) {
                    Picker("Change Type To:", selection: $selectedType) {
                        Text("Workday").tag(DayType.workday)
                        Text("Earned Off Day").tag(DayType.earnedOffDay)
                        Text("Vacation").tag(DayType.vacation)
                        Text("Training").tag(DayType.training)
                        Text("Company Off").tag(DayType.companyOff)
                    }
                    
                    TextField("Override Notes", text: $customNotes)
                        .font(DesignTokens.Typography.body)
                    
                    Button(action: {
                        showingOverrideConfirmation = true
                    }) {
                        Text("Apply Override")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Color.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .alert(isPresented: $showingOverrideConfirmation) {
                        Alert(
                            title: Text("Confirm Override"),
                            message: Text("This will disable automatic scheduling for the current hitch. Continue?"),
                            primaryButton: .destructive(Text("Override")) {
                                applyManualOverride()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
                
                // Add button to create interruption starting from this day
                Section {
                    Button(action: {
                        viewModel.selectedDate = date
                        viewModel.showingInterruptionSheet = true
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Create Interruption From This Day")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Color.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Day Details")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                selectedType = dayType
                customNotes = notes ?? ""
            }
        }
    }
    
    private var formattedDate: String {
        return FormattingUtilities.formatDate(date)
    }
    
    private func getColorForDayType() -> Color {
        return ColorTheme.foregroundColor(for: dayType)
    }
    
    private func getHitchPositionDescription() -> String {
        let position = hitchPosition % 21 + 1 // Convert from 0-indexed to 1-indexed for display
        
        if position <= 14 {
            return "Work Day \(position) of 14"
        } else {
            return "Off Day \(position - 14) of 7"
        }
    }
    
    private func applyManualOverride() {
        viewModel.applyManualOverride(for: date, type: selectedType, notes: customNotes.isEmpty ? nil : customNotes)
        
        // Dismiss the sheet after applying
        presentationMode.wrappedValue.dismiss()
    }
}

struct DayDetailView_Previews: PreviewProvider {
    static var previews: some View {
        DayDetailView(
            date: Date(),
            dayType: .workday,
            isOverride: false,
            notes: "Regular workday",
            hitchPosition: 0,
            viewModel: WorkScheduleViewModel()
        )
    }
} 