import SwiftUI

/// Shared month and year picker component used across the app
struct MonthYearPicker: View {
    @Binding var selectedDate: Date
    
    @State private var selectedMonth: Int
    @State private var selectedYear: Int
    
    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: selectedDate.wrappedValue)
        _selectedMonth = State(initialValue: components.month ?? 1)
        _selectedYear = State(initialValue: components.year ?? calendar.component(.year, from: Date()))
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Month Picker
                Picker("Month", selection: $selectedMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(monthName(month)).tag(month)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: geometry.size.width / 2)
                .onChange(of: selectedMonth) { updateDate() }
                
                // Year Picker
                Picker("Year", selection: $selectedYear) {
                    ForEach(2020...2030, id: \.self) { year in
                        Text("\(year)").tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: geometry.size.width / 2)
                .onChange(of: selectedYear) { updateDate() }
            }
        }
        .frame(height: 200)
        .padding()
    }
    
    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let date = Calendar.current.date(from: DateComponents(year: 2024, month: month, day: 1))!
        return formatter.string(from: date)
    }
    
    private func updateDate() {
        let calendar = Calendar.current
        if let newDate = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) {
            selectedDate = newDate
        }
    }
}



