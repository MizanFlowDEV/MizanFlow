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
                Section(header: Text("Day Information")) {
                    HStack {
                        Text("Date:")
                        Spacer()
                        Text(formattedDate)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Type:")
                        Spacer()
                        Text(viewModel.getDayDescription(for: dayType))
                            .foregroundColor(getColorForDayType())
                    }
                    
                    if isOverride {
                        HStack {
                            Text("Manual Override:")
                            Spacer()
                            Text("Yes")
                                .foregroundColor(.red)
                        }
                    }
                    
                    HStack {
                        Text("Hitch Position:")
                        Spacer()
                        Text(getHitchPositionDescription())
                            .foregroundColor(hitchPosition < 14 ? .blue : .gray)
                    }
                    
                    if let overtime = viewModel.getOvertimeHours(for: date), overtime > 0 {
                        HStack {
                            Text("Overtime Hours:")
                            Spacer()
                            Text("\(Int(overtime)) hrs")
                                .foregroundColor(.green)
                        }
                    }
                    
                    if viewModel.hasIcon(for: date), let iconName = viewModel.getIconName(for: date) {
                        HStack {
                            Text("Special Mark:")
                            Spacer()
                            Image(systemName: iconName)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                if let notes = notes, !notes.isEmpty {
                    Section(header: Text("Notes")) {
                        Text(notes)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Only show manual override options if not already overridden
                // or if user is viewing an overridden day
                Section(header: Text("Manual Override")) {
                    Picker("Change Type To:", selection: $selectedType) {
                        Text("Workday").tag(DayType.workday)
                        Text("Earned Off Day").tag(DayType.earnedOffDay)
                        Text("Vacation").tag(DayType.vacation)
                        Text("Training").tag(DayType.training)
                        Text("Company Off").tag(DayType.companyOff)
                    }
                    
                    TextField("Override Notes", text: $customNotes)
                    
                    Button(action: {
                        showingOverrideConfirmation = true
                    }) {
                        Text("Apply Override")
                            .foregroundColor(.blue)
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
                            .foregroundColor(.blue)
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