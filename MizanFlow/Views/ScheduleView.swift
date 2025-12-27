import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var viewModel: WorkScheduleViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingHitchStartPicker = false
    @State private var hitchStartDate = Date()
    @State private var showingInterruptionsHistorySheet = false
    @State private var showingRemoveInterruptionAlert = false
    @State private var calendarRefreshToggle = false
    
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top bar with Hitch Start Date button
                HStack {
                    Button(action: {
                        HapticFeedback.buttonTap()
                        showingHitchStartPicker = true
                    }) {
                        Label(NSLocalizedString("Set Hitch Start Date", comment: "Set hitch start date button"), systemImage: "calendar.badge.plus")
                            .font(.subheadline)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .accessibilityLabel(NSLocalizedString("Set Hitch Start Date", comment: "Set hitch start date accessibility"))
                    
                    Spacer()
                    
                    // Show current hitch pattern
                    if viewModel.hitchStartDate != nil {
                        Text("14/7 Hitch")
                            .font(.caption)
                            .padding(6)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                .padding([.top, .horizontal])
                
                // Month selector
                HStack {
                    Button(action: {
                        HapticFeedback.calendarNavigation()
                        previousMonth()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel(NSLocalizedString("Previous month", comment: "Previous month button"))
                    Spacer()
                    Text(viewModel.getMonthString(viewModel.selectedDate))
                        .font(.title2)
                        .bold()
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button(action: {
                        HapticFeedback.calendarNavigation()
                        nextMonth()
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel(NSLocalizedString("Next month", comment: "Next month button"))
                }
                .padding(.horizontal)
                .padding(.top, 4)
                
                // Weekday headers
                HStack {
                    ForEach(viewModel.getWeekdaySymbols(), id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Calendar grid (always 6 rows)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(getCalendarGrid(), id: \.id) { cell in
                            if let day = cell.day {
                                DayCell(day: day, isOverride: viewModel.isOverride(for: day.date))
                                    .onTapGesture {
                                        HapticFeedback.dateSelection()
                                        viewModel.selectedDate = day.date
                                        viewModel.showingDayDetail = true
                                    }
                                    .accessibilityCalendarCell(
                                        day: Calendar.current.component(.day, from: day.date),
                                        type: day.type.description,
                                        isSelected: Calendar.current.isDate(day.date, inSameDayAs: viewModel.selectedDate)
                                    )
                            } else {
                                Color.clear
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                    .padding()
                    .id(calendarRefreshToggle) // Force grid to refresh when this value changes
                }
                
                // Legend
                calendarLegend
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { viewModel.showingInterruptionSheet = true }) {
                            Label(NSLocalizedString("Add Interruption", comment: "Add interruption button"), systemImage: "calendar.badge.exclamationmark")
                        }
                        .accessibilityLabel(NSLocalizedString("Add Interruption", comment: "Add interruption accessibility"))
                        
                        Button(action: { showingInterruptionsHistorySheet = true }) {
                            Label(NSLocalizedString("View Interruptions", comment: "View interruptions button"), systemImage: "list.bullet")
                        }
                        .accessibilityLabel(NSLocalizedString("View Interruptions", comment: "View interruptions accessibility"))
                        
                        if viewModel.schedule.isInterrupted {
                            Button(action: { 
                                showRemoveInterruptionAlert()
                            }) {
                                Label(NSLocalizedString("Remove Interruption", comment: "Remove interruption button"), systemImage: "trash")
                            }
                            .accessibilityLabel(NSLocalizedString("Remove Interruption", comment: "Remove interruption accessibility"))
                        }
                        
                        if viewModel.schedule.manuallyAdjusted {
                            Button(action: { viewModel.resetManualAdjustments() }) {
                                Label(NSLocalizedString("Reset Manual Overrides", comment: "Reset manual overrides button"), systemImage: "arrow.clockwise")
                            }
                            .accessibilityLabel(NSLocalizedString("Reset Manual Overrides", comment: "Reset manual overrides accessibility"))
                        }
                        
                        Divider()
                        
                        Button(action: { viewModel.testSuggestMode() }) {
                            Label(NSLocalizedString("Test Suggest Mode", comment: "Test suggest mode button"), systemImage: "brain.head.profile")
                        }
                        .accessibilityLabel(NSLocalizedString("Test Suggest Mode", comment: "Test suggest mode accessibility"))
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingHitchStartPicker) {
                NavigationView {
                    VStack {
                        HStack {
                            Text("Set Hitch Start Date")
                                .font(.headline)
                                .padding()
                            Spacer()
                        }
                        
                        Text("This will generate a 14/7 hitch pattern starting from this date.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        DatePicker("", selection: $hitchStartDate, displayedComponents: .date)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .padding()
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.setHitchStartDate(hitchStartDate)
                            showingHitchStartPicker = false
                        }) {
                            Text("Done")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding()
                    }
                    .navigationTitle("Set Hitch Start Date")
                    .navigationBarItems(trailing: Button("Done") {
                        viewModel.setHitchStartDate(hitchStartDate)
                        showingHitchStartPicker = false
                    })
                }
            }
            .sheet(isPresented: $viewModel.showingDayDetail) {
                DayDetailView(
                    date: viewModel.selectedDate,
                    dayType: viewModel.getDayType(for: viewModel.selectedDate),
                    isOverride: viewModel.isOverride(for: viewModel.selectedDate),
                    notes: viewModel.getNotes(for: viewModel.selectedDate),
                    hitchPosition: viewModel.getHitchDayPosition(for: viewModel.selectedDate),
                    viewModel: viewModel
                )
            }
            .sheet(isPresented: $viewModel.showingInterruptionSheet) {
                InterruptionSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingInterruptionsHistorySheet) {
                InterruptionsHistoryView(viewModel: viewModel)
            }
            .alert(isPresented: $viewModel.showingRescheduleAlert) {
                Alert(
                    title: Text("Schedule Update"),
                    message: Text(viewModel.rescheduleMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert(isPresented: $showingRemoveInterruptionAlert) {
                Alert(
                    title: Text("Remove Interruption"),
                    message: Text("Are you sure you want to remove this interruption? Your schedule will be restored to its original pattern."),
                    primaryButton: .destructive(Text("Remove")) {
                        viewModel.removeCurrentInterruption()
                        // Force view to update by slightly delaying the state update
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // This will ensure the view refreshes completely
                            viewModel.objectWillChange.send()
                            calendarRefreshToggle.toggle() // Force calendar grid to refresh
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    // Helper for consistent 6-row grid
    private struct CalendarCell: Hashable, Equatable {
        let id: UUID
        let day: WorkSchedule.ScheduleDay?
        let date: Date
        
        init(day: WorkSchedule.ScheduleDay?) {
            self.id = day?.id ?? UUID()
            self.day = day
            self.date = day?.date ?? Date()
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(date)
        }
        
        static func == (lhs: CalendarCell, rhs: CalendarCell) -> Bool {
            lhs.id == rhs.id && 
            Calendar.current.isDate(lhs.date, inSameDayAs: rhs.date) &&
            lhs.day?.type == rhs.day?.type &&
            lhs.day?.isOverride == rhs.day?.isOverride
        }
    }
    private func getCalendarGrid() -> [CalendarCell] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: viewModel.selectedDate)
        guard let firstDayOfMonth = calendar.date(from: components),
              let totalDaysInMonth = calendar.range(of: .day, in: .month, for: firstDayOfMonth)?.count else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        var grid: [CalendarCell] = []

        // Add leading days from previous month (only those in the first week)
        if firstWeekday > 1 {
            for i in stride(from: firstWeekday - 2, through: 0, by: -1) {
                if let date = calendar.date(byAdding: .day, value: -i - 1, to: firstDayOfMonth) {
                    createAndAddCalendarCell(for: date, to: &grid)
                }
            }
        }

        // Add days of current month
        for day in 1...totalDaysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                createAndAddCalendarCell(for: date, to: &grid)
            }
        }

        // Add trailing days from next month (only those in the last week)
        if let lastDayOfMonth = calendar.date(byAdding: DateComponents(day: totalDaysInMonth - 1), to: firstDayOfMonth) {
            let lastWeekday = calendar.component(.weekday, from: lastDayOfMonth)
            if lastWeekday < 7 {
                for i in 1...(7 - lastWeekday) {
                    if let date = calendar.date(byAdding: .day, value: i, to: lastDayOfMonth) {
                        createAndAddCalendarCell(for: date, to: &grid)
                    }
                }
            }
        }

        return grid
    }
    
    // Helper function to create and add a calendar cell for a given date
    private func createAndAddCalendarCell(for date: Date, to grid: inout [CalendarCell]) {
        let calendar = Calendar.current
        
        // Check if we can find this day in the schedule
        if let scheduleDay = viewModel.schedule.days.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            // Make a copy of the schedule day to ensure we can modify it safely
            var modifiedDay = scheduleDay
            
            // For days outside current month, ensure isInHitch is correctly set
            if let hitchStart = viewModel.hitchStartDate {
                let daysSinceStart = calendar.dateComponents([.day], from: hitchStart, to: date).day ?? 0
                let cyclePosition = (daysSinceStart % 21 + 21) % 21 // Ensure positive
                modifiedDay.isInHitch = cyclePosition < 14
            } else {
                modifiedDay.isInHitch = false // Default to false if no hitch start date
            }
            
            grid.append(CalendarCell(day: modifiedDay))
        } else {
            // Check if this date is before the hitch start date
            let isBeforeHitchStart = if let hitchStart = viewModel.hitchStartDate {
                date < hitchStart
            } else {
                true // If no hitch start date, treat as before hitch
            }
            
            if isBeforeHitchStart {
                // For days before hitch start, create a placeholder day without any status
                let placeholderDay = WorkSchedule.ScheduleDay(
                    id: UUID(),
                    date: date,
                    type: .workday, // neutral base type; we'll suppress its display
                    isHoliday: false,
                    isOverride: false,
                    notes: nil,
                    overtimeHours: nil,
                    isInHitch: false, // Not in hitch
                    hasIcon: false,
                    iconName: nil,
                    isPlaceholder: true // Mark as placeholder for UI display
                )
                grid.append(CalendarCell(day: placeholderDay))
            } else {
                // Create a placeholder day with the correct date for days after hitch start
                let placeholderDay = WorkSchedule.ScheduleDay(
                    id: UUID(),
                    date: date,
                    type: .earnedOffDay, // Default type for placeholders
                    isHoliday: false, // Default to false for placeholder days
                    isOverride: false,
                    notes: nil,
                    overtimeHours: nil,
                    isInHitch: false, // Always outside hitch for placeholder days
                    hasIcon: false,
                    iconName: nil
                )
                grid.append(CalendarCell(day: placeholderDay))
            }
        }
    }
    
    private func previousMonth() {
        if let newDate = Calendar.current.date(byAdding: .month, value: -1, to: viewModel.selectedDate) {
            viewModel.selectedDate = newDate
        }
    }
    
    private func nextMonth() {
        if let newDate = Calendar.current.date(byAdding: .month, value: 1, to: viewModel.selectedDate) {
            viewModel.selectedDate = newDate
        }
    }
    
    // Calendar legend view
    private var calendarLegend: some View {
        let legendOrder: [DayType] = [
            .workday, .earnedOffDay, .vacation, .training, .eidHoliday, .nationalDay, .foundingDay, .autoRescheduled, .companyOff, .manualOverride, .ramadan
        ]
        return VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("14/7 Hitch Pattern", comment: ""))
                .font(.caption)
                .fontWeight(.bold)
                .padding(.bottom, 2)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(legendOrder, id: \.self) { type in
                        legendItem(color: color(for: type), label: NSLocalizedString(type.description, comment: ""))
                    }
                }
                .padding(.vertical, 8)
            }
            
            if viewModel.schedule.isInterrupted {
                interruptionIndicator
            }
        }
    }
    
    // Helper to get the color for a given DayType (matches DayCell)
    private func color(for type: DayType) -> Color {
        return ColorTheme.legendColor(for: type)
    }
    
    // Interruption indicator for active interruptions
    private var interruptionIndicator: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
                .padding(.vertical, 4)
            
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                
                Text("Active Interruption")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            
            if let start = viewModel.schedule.interruptionStart,
               let end = viewModel.schedule.interruptionEnd,
               let type = viewModel.schedule.interruptionType {
                
                Text("\(type.rawValue.capitalized): \(formatDate(start)) - \(formatDate(end))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.schedule.manuallyAdjusted {
                Text("Manual override detected")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
    
    // Date formatter helper
    private func formatDate(_ date: Date) -> String {
        return FormattingUtilities.formatShortDate(date)
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 16, height: 16)
            Text(label)
                .font(.caption)
        }
    }
    
    private func showRemoveInterruptionAlert() {
        showingRemoveInterruptionAlert = true
    }
}

struct DayCell: View {
    let day: WorkSchedule.ScheduleDay
    let isOverride: Bool
    
    var body: some View {
        ZStack {
            backgroundColor
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isOverride ? Color.red : Color.gray.opacity(0.2), lineWidth: isOverride ? 2 : 1)
                )
            
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: day.date))")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textColor)
                
                // Only show day label if the day is in a hitch or has special status
                if shouldShowDayLabel {
                    Text(dayLabel)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                
                if day.hasIcon, let iconName = day.iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 10))
                        .foregroundColor(.primary.opacity(0.7))
                }
                
                if isOverride {
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 20, height: 2)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
    
    private var shouldShowDayLabel: Bool {
        // Pre-hitch placeholders: never show labels
        if day.isPlaceholder == true { return false }
        
        // Special days (holidays): always show labels
        if isSpecialDayType { return true }
        
        // Days in active hitch: always show labels
        if day.isInHitch { return true }
        
        // Off days after hitch start: show labels
        if day.type == .earnedOffDay || day.type == .companyOff { return true }
        
        // Default: show labels for all other days
        return true
    }
    
    private var isSpecialDayType: Bool {
        switch day.type {
        case .vacation, .training, .eidHoliday, .nationalDay, .foundingDay, .autoRescheduled, .manualOverride, .ramadan:
            return true
        case .workday, .earnedOffDay, .companyOff:
            return false
        }
    }
    
    private var backgroundColor: Color {
        // Pre-hitch placeholders: clear background
        if day.isPlaceholder == true { return Color.clear }
        
        return ColorTheme.backgroundColor(for: day.type)
    }
    
    private var textColor: Color {
        return ColorTheme.textColor(for: day.type)
    }
    
    private var dayLabel: String {
        switch day.type {
        case .workday:
            return NSLocalizedString("Work", comment: "")
        case .earnedOffDay, .companyOff:
            return NSLocalizedString("Off", comment: "")
        case .vacation:
            return NSLocalizedString("Vacation", comment: "")
        case .training:
            return NSLocalizedString("Training", comment: "")
        case .eidHoliday:
            return NSLocalizedString("Eid Holiday", comment: "")
        case .nationalDay:
            return NSLocalizedString("National Day", comment: "")
        case .foundingDay:
            return NSLocalizedString("Founding Day", comment: "")
        case .autoRescheduled:
            return NSLocalizedString("Rescheduled Day", comment: "")
        case .manualOverride:
            return NSLocalizedString("Manual Override", comment: "")
        case .ramadan:
            return NSLocalizedString("Ramadan", comment: "")
        }
    }
} 
