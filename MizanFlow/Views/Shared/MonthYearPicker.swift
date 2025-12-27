import SwiftUI

/// Shared month and year picker component used across the app
struct MonthYearPicker: View {
    @Binding var selectedDate: Date
    
    var body: some View {
        DatePicker(
            "Select Month and Year",
            selection: $selectedDate,
            displayedComponents: [.date]
        )
        .datePickerStyle(.wheel)
        .labelsHidden()
        .padding()
    }
}



