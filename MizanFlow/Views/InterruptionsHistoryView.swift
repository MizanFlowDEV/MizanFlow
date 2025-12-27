import SwiftUI

struct InterruptionsHistoryView: View {
    @ObservedObject var viewModel: WorkScheduleViewModel
    @Environment(\.presentationMode) private var presentationMode
    @State private var showingRemoveAlert = false
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.schedule.isInterrupted {
                    Section(header: Text("Current Interruption")) {
                        if let start = viewModel.schedule.interruptionStart,
                           let end = viewModel.schedule.interruptionEnd,
                           let type = viewModel.schedule.interruptionType {
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(type.rawValue.capitalized)")
                                        .font(.headline)
                                    
                                    Text("\(formatDate(start)) to \(formatDate(end))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    if let returnDay = viewModel.schedule.preferredReturnDay {
                                        Text("Returns on: \(returnDay.description)")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                            .padding(.top, 4)
                                    }
                                }
                                
                                Spacer()
                                
                                if viewModel.schedule.manuallyAdjusted {
                                    Text("Manual")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red)
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.vertical, 4)
                            
                            // Stats about the interruption
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Workdays before: \(viewModel.getWorkedDaysBeforeInterruption())")
                                    .font(.caption)
                                
                                Text("Earned off days: \(viewModel.getEarnedOffDaysBeforeInterruption())")
                                    .font(.caption)
                                
                                if type == .vacation {
                                    Text("Vacation balance: \(viewModel.getVacationBalance()) days")
                                        .font(.caption)
                                }
                            }
                            .padding(.top, 4)
                            
                            // Remove interruption button
                            Button(action: {
                                showingRemoveAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                    Text("Remove Interruption")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                } else {
                    Section {
                        Text("No active interruptions")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Actions")) {
                    Button(action: {
                        viewModel.showingInterruptionSheet = true
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Label("Add New Interruption", systemImage: "plus.circle")
                    }
                    
                    if viewModel.schedule.manuallyAdjusted {
                        Button(action: {
                            viewModel.resetManualAdjustments()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Label("Reset Manual Overrides", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
            .navigationTitle("Interruptions")
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showingRemoveAlert) {
                Alert(
                    title: Text("Remove Interruption"),
                    message: Text("Are you sure you want to remove this interruption? Your schedule will be restored to its original pattern."),
                    primaryButton: .destructive(Text("Remove")) {
                        viewModel.removeCurrentInterruption()
                        // Force view to update by slightly delaying the state update
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // This will ensure the view refreshes completely
                            viewModel.objectWillChange.send()
                        }
                        presentationMode.wrappedValue.dismiss()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    // Date formatter helper
    private func formatDate(_ date: Date) -> String {
        return FormattingUtilities.formatDate(date)
    }
} 