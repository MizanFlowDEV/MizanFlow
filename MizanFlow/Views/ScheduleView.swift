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
                HStack(spacing: DesignTokens.Spacing.md) {
                    Button(action: {
                        HapticFeedback.buttonTap()
                        showingHitchStartPicker = true
                    }) {
                        Label(NSLocalizedString("Set Hitch Start Date", comment: "Set hitch start date button"), systemImage: "calendar.badge.plus")
                            .font(DesignTokens.Typography.caption)
                            .frame(minHeight: DesignTokens.Calendar.minCellSize)
                            .padding(.horizontal, DesignTokens.Spacing.md)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .accessibilityLabel(NSLocalizedString("Set Hitch Start Date", comment: "Set hitch start date accessibility"))
                    .accessibilityHint(NSLocalizedString("Tap to set the start date for your work schedule", comment: ""))
                    
                    Spacer()
                    
                    // Show current hitch pattern
                    if viewModel.hitchStartDate != nil {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(DesignTokens.Color.success)
                                .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                            Text("14/7 Hitch")
                                .font(DesignTokens.Typography.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(DesignTokens.Color.success.opacity(0.15))
                        .cornerRadius(DesignTokens.CornerRadius.medium)
                    }
                }
                .padding([.top, .horizontal], DesignTokens.Spacing.md)
                
                // Month selector
                HStack {
                    Button(action: {
                        HapticFeedback.calendarNavigation()
                        previousMonth()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(DesignTokens.Color.textPrimary)
                            .font(.system(size: DesignTokens.Icon.large, weight: DesignTokens.Icon.weight))
                            .frame(width: DesignTokens.Calendar.minCellSize, height: DesignTokens.Calendar.minCellSize)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(NSLocalizedString("Previous month", comment: "Previous month button"))
                    .accessibilityHint(NSLocalizedString("Tap to view the previous month", comment: ""))
                    
                    Spacer()
                    
                    Text(viewModel.getMonthString(viewModel.selectedDate))
                        .font(DesignTokens.Typography.screenTitle)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .accessibilityAddTraits(.isHeader)
                    
                    Spacer()
                    
                    Button(action: {
                        HapticFeedback.calendarNavigation()
                        nextMonth()
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(DesignTokens.Color.textPrimary)
                            .font(.system(size: DesignTokens.Icon.large, weight: DesignTokens.Icon.weight))
                            .frame(width: DesignTokens.Calendar.minCellSize, height: DesignTokens.Calendar.minCellSize)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(NSLocalizedString("Next month", comment: "Next month button"))
                    .accessibilityHint(NSLocalizedString("Tap to view the next month", comment: ""))
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.top, DesignTokens.Spacing.sm)
                
                // Weekday headers
                HStack {
                    ForEach(viewModel.getWeekdaySymbols(), id: \.self) { symbol in
                        Text(symbol)
                            .font(DesignTokens.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignTokens.Color.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                
                // Calendar grid (always 6 rows)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: DesignTokens.Calendar.cellSpacing) {
                        ForEach(getCalendarGrid(), id: \.id) { cell in
                            if let day = cell.day {
                                DayCell(
                                    day: day,
                                    isOverride: viewModel.isOverride(for: day.date),
                                    isSelected: Calendar.current.isDate(day.date, inSameDayAs: viewModel.selectedDate),
                                    isToday: Calendar.current.isDateInToday(day.date)
                                )
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
                                    .accessibilityLabel("\(day.type.description), \(Calendar.current.component(.day, from: day.date))")
                                    .accessibilityHint("Tap to view details for this day")
                            } else {
                                Color.clear
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                    .padding(DesignTokens.Spacing.md)
                    .id(calendarRefreshToggle) // Force grid to refresh when this value changes
                }
                
                // Legend
                calendarLegend
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.sm)
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
                                .font(DesignTokens.Typography.sectionTitle)
                                .padding(DesignTokens.Spacing.md)
                            Spacer()
                        }
                        
                        Text("This will generate a 14/7 hitch pattern starting from this date.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Color.textSecondary)
                            .padding(.horizontal, DesignTokens.Spacing.md)
                        
                        DatePicker("", selection: $hitchStartDate, displayedComponents: .date)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .padding(DesignTokens.Spacing.md)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.setHitchStartDate(hitchStartDate)
                            showingHitchStartPicker = false
                        }) {
                            Text("Done")
                                .font(DesignTokens.Typography.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(DesignTokens.Spacing.md)
                                .background(DesignTokens.Color.primary)
                                .cornerRadius(DesignTokens.CornerRadius.large)
                        }
                        .padding(DesignTokens.Spacing.md)
                    }
                    .navigationTitle("Set Hitch Start Date")
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
                        // Force calendar grid to refresh (SwiftUI will automatically update via @Published properties)
                        calendarRefreshToggle.toggle()
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
        // Note: totalDaysInMonth - 1 is correct because we're 0-indexed (day 1 = offset 0, day N = offset N-1)
        // This calculates the last day of the current month
        if let lastDayOfMonth = calendar.date(byAdding: DateComponents(day: totalDaysInMonth - 1), to: firstDayOfMonth) {
            let lastWeekday = calendar.component(.weekday, from: lastDayOfMonth)
            if lastWeekday < 7 {
                // Add days from next month to complete the last week (up to 6 days)
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
        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(NSLocalizedString("14/7 Hitch Pattern", comment: ""))
                .font(DesignTokens.Typography.sectionTitle)
                .padding(.bottom, DesignTokens.Spacing.xs)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(legendOrder, id: \.self) { type in
                        legendItem(type: type)
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
            }
            
            if viewModel.schedule.isInterrupted {
                interruptionIndicator
            }
        }
    }
    
    // Interruption indicator for active interruptions
    private var interruptionIndicator: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Divider()
                .padding(.vertical, DesignTokens.Spacing.xs)
            
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(DesignTokens.Color.warning)
                    .font(.system(size: DesignTokens.Icon.medium, weight: DesignTokens.Icon.weight))
                
                Text("Active Interruption")
                    .font(DesignTokens.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignTokens.Color.warning)
            }
            
            if let start = viewModel.schedule.interruptionStart,
               let end = viewModel.schedule.interruptionEnd,
               let type = viewModel.schedule.interruptionType {
                
                Text("\(type.rawValue.capitalized): \(formatDate(start)) - \(formatDate(end))")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Color.textSecondary)
            }
            
            if viewModel.schedule.manuallyAdjusted {
                Text("Manual override detected")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Color.error)
                    .padding(.top, DesignTokens.Spacing.xs)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
    
    // Date formatter helper
    private func formatDate(_ date: Date) -> String {
        return FormattingUtilities.formatShortDate(date)
    }
    
    // Legend item matching simplified cell design (background + indicator)
    private func legendItem(type: DayType) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            // Mini cell representation
            ZStack {
                ColorTheme.backgroundColor(for: type)
                    .cornerRadius(DesignTokens.CornerRadius.small)
                    .frame(width: 24, height: 24)
                
                // Indicator (dot + bar)
                HStack(spacing: 1) {
                    Circle()
                        .fill(ColorTheme.indicatorColor(for: type))
                        .frame(width: 3, height: 3)
                    
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(ColorTheme.indicatorColor(for: type))
                        .frame(width: 8, height: 1)
                }
                .offset(y: 6)
            }
            
            Text(NSLocalizedString(type.description, comment: ""))
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Color.textPrimary)
        }
    }
    
    private func showRemoveInterruptionAlert() {
        showingRemoveInterruptionAlert = true
    }
}

struct DayCell: View {
    let day: WorkSchedule.ScheduleDay
    let isOverride: Bool
    let isSelected: Bool
    let isToday: Bool
    
    var body: some View {
        ZStack {
            // Background with subtle tint
            backgroundColor
                .cornerRadius(DesignTokens.CornerRadius.medium)
            
            // Border for today/selected/override states
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                .stroke(borderColor, lineWidth: borderWidth)
            
            VStack(spacing: DesignTokens.Spacing.xs) {
                // Day number
                Text("\(Calendar.current.component(.day, from: day.date))")
                    .font(DesignTokens.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(textColor)
                
                Spacer()
                
                // Status indicator (dot + bar combination)
                if !isPlaceholder {
                    HStack(spacing: 2) {
                        // Small dot indicator
                        Circle()
                            .fill(indicatorColor)
                            .frame(width: DesignTokens.Calendar.indicatorSize, height: DesignTokens.Calendar.indicatorSize)
                        
                        // Thin bar indicator
                        RoundedRectangle(cornerRadius: 1)
                            .fill(indicatorColor)
                            .frame(height: DesignTokens.Calendar.indicatorBarHeight)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.xs)
                    .padding(.bottom, DesignTokens.Spacing.xs)
                }
            }
            .padding(DesignTokens.Spacing.xs)
        }
        .frame(maxWidth: .infinity, minHeight: DesignTokens.Calendar.minCellSize)
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
    }
    
    private var isPlaceholder: Bool {
        day.isPlaceholder == true
    }
    
    private var backgroundColor: Color {
        if isPlaceholder {
            return Color.clear
        }
        return ColorTheme.backgroundColor(for: day.type)
    }
    
    private var textColor: Color {
        if isPlaceholder {
            return DesignTokens.Color.textSecondary
        }
        return ColorTheme.textColor(for: day.type)
    }
    
    private var indicatorColor: Color {
        if isOverride {
            return DesignTokens.Color.override
        }
        return ColorTheme.indicatorColor(for: day.type)
    }
    
    private var borderColor: Color {
        if isOverride {
            return DesignTokens.Color.override
        } else if isToday {
            return DesignTokens.Color.primary
        } else if isSelected {
            return DesignTokens.Color.primary.opacity(0.5)
        } else {
            return DesignTokens.Color.separator.opacity(0.3)
        }
    }
    
    private var borderWidth: CGFloat {
        if isOverride || isToday || isSelected {
            return DesignTokens.Calendar.borderWidth
        }
        return 1
    }
} 
