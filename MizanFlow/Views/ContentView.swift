import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject var scheduleViewModel: WorkScheduleViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ScheduleView()
                .tabItem {
                    Label(NSLocalizedString("Schedule", comment: ""), systemImage: "calendar")
                }
                .tag(0)
            
            SalaryView()
                .tabItem {
                    Label(NSLocalizedString("Salary", comment: ""), systemImage: "dollarsign.circle")
                }
                .tag(1)
            
            BudgetView()
                .tabItem {
                    Label(NSLocalizedString("Budget", comment: ""), systemImage: "chart.pie")
                }
                .tag(2)
            
            SettingsView(scheduleViewModel: scheduleViewModel)
                .tabItem {
                    Label(NSLocalizedString("Settings", comment: ""), systemImage: "gear")
                }
                .tag(3)
        }
        .accentColor(settingsViewModel.getThemeColor())
        // Note: layoutDirection is already set in MizanFlowApp, no need to set it again here
    }
}

#Preview {
    ContentView()
        .environmentObject(SettingsViewModel())
        .environmentObject(WorkScheduleViewModel())
} 