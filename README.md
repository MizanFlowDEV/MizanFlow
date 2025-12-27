# MizanFlow

A comprehensive iOS application for managing work schedules, calculating salaries, and tracking budgets for shift workers, particularly designed for the 14/7 hitch pattern common in Saudi Arabia.

## 📱 Overview

MizanFlow is a native iOS app built with SwiftUI that helps shift workers manage their complex work schedules, accurately calculate their monthly salaries including overtime and allowances, and track their personal budgets. The app is fully localized in Arabic and English, with support for RTL (Right-to-Left) layouts.

### Key Highlights

- **Work Schedule Management**: Automatically generates and manages 14-day work / 7-day off hitch patterns
- **Salary Calculator**: Precise calculations for base salary, overtime, allowances, and deductions (GOSI, SANID, etc.)
- **Budget Tracker**: Comprehensive income and expense tracking with category breakdowns
- **Bilingual Support**: Full Arabic and English localization with RTL support
- **Smart Features**: Holiday detection, interruption handling, and intelligent schedule suggestions

## ✨ Features

### 📅 Schedule Management

- **14/7 Hitch Pattern**: Automatically generates work schedules based on the 14 days work / 7 days off pattern
- **Holiday Detection**: Automatically identifies and marks public holidays (Eid, National Day, Founding Day, Ramadan)
- **Interruption Handling**: Manage vacations, training, short leaves, and company-off days
- **Manual Overrides**: Override specific days with custom day types
- **Visual Calendar**: Color-coded calendar view showing different day types
- **Vacation Balance Tracking**: Track remaining vacation days
- **Smart Rescheduling**: Intelligent suggestions for rescheduling after interruptions

### 💰 Salary Calculator

- **Base Salary**: Monthly base salary input
- **Overtime Calculation**: Automatic overtime pay calculation based on hours worked
- **ADL Hours**: Additional Straight Time (ADL) hours tracking and calculation
- **Allowances**:
  - Remote Location Allowance (14% of base salary)
  - Special Operations Allowance (5%, 7%, or 10% of base salary)
  - Transportation Allowance (Fixed 1000 SAR)
- **Deductions**:
  - Home Loan (25% to 50% of base salary)
  - ESPP (1% to 10% of base salary)
  - GOSI (11.25% of base salary)
  - SANID (0.93% of base salary)
  - Custom deductions
- **Additional Income**: Track extra income sources
- **Net Pay Calculation**: Automatic calculation of total compensation minus deductions

### 💵 Budget Tracker

- **Income & Expenses**: Track both income and expenses in one place
- **Category Management**: Organize entries by categories (Housing, Transportation, Utilities, Groceries, Entertainment, Savings, Investments, Healthcare, Education, Other)
- **Monthly View**: Filter and view entries by month
- **Recurring Entries**: Support for recurring income/expenses
- **Category Breakdown**: Visual breakdown of spending by category
- **Savings Rate**: Automatic calculation of savings rate percentage
- **Net Balance**: Real-time calculation of net balance (income - expenses)

### 🌍 Localization

- **Bilingual Support**: Full support for English and Arabic
- **RTL Layout**: Proper Right-to-Left layout support for Arabic
- **Dynamic Language Switching**: Change language on the fly
- **Localized Dates & Numbers**: Proper formatting based on selected language

### ⚙️ Settings & Preferences

- **Theme Selection**: Light, Dark, or System theme
- **Language Selection**: Switch between English and Arabic
- **Notifications**: Enable/disable smart alerts
- **Low Off Days Threshold**: Configure threshold for off-day warnings
- **Data Export**: Export settings and data for backup
- **Version Information**: Display app version and build number

### 🔔 Smart Alerts

- **Low Off Days Warning**: Alerts when off days fall below threshold
- **Salary Changes**: Notifications for significant salary increases or decreases
- **Holiday Conflicts**: Warnings for schedule conflicts with holidays
- **Monthly Suggestions**: Intelligent suggestions for schedule optimization

### 💾 Data Management

- **Core Data Persistence**: All data stored locally using Core Data
- **Automatic Saving**: Changes saved automatically when app goes to background
- **Data Export**: Export schedules and settings to JSON
- **Data Import**: Import previously exported data
- **Backup Service**: Comprehensive backup and restore functionality

## 🏗️ Architecture

### Technology Stack

- **Language**: Swift 5.0
- **UI Framework**: SwiftUI
- **Data Persistence**: Core Data
- **Architecture Pattern**: MVVM (Model-View-ViewModel)
- **Minimum iOS Version**: iOS 18.4
- **Platform**: iPhone and iPad

### Project Structure

```
MizanFlow/
├── MizanFlowApp.swift          # App entry point
├── Models/                      # Data models
│   ├── BudgetEntry.swift
│   ├── SalaryBreakdown.swift
│   ├── Settings.swift
│   ├── WorkSchedule.swift
│   └── AppError.swift
├── ViewModels/                 # View models (MVVM)
│   ├── BudgetViewModel.swift
│   ├── SalaryViewModel.swift
│   ├── SettingsViewModel.swift
│   └── WorkScheduleViewModel.swift
├── Views/                      # SwiftUI views
│   ├── ContentView.swift
│   ├── ScheduleView.swift
│   ├── SalaryView.swift
│   ├── BudgetView.swift
│   ├── SettingsView.swift
│   ├── DayDetailView.swift
│   ├── InterruptionSheet.swift
│   ├── InterruptionsHistoryView.swift
│   └── Shared/                # Shared view components
├── Services/                   # Business logic services
│   ├── SalaryEngine.swift
│   ├── ScheduleEngine.swift
│   ├── HolidayService.swift
│   ├── BackupService.swift
│   ├── DataPersistenceService.swift
│   └── SmartAlertService.swift
├── Utilities/                 # Helper utilities
│   ├── AppLogger.swift
│   ├── ColorTheme.swift
│   ├── FormattingUtilities.swift
│   ├── ValidationUtilities.swift
│   ├── AccessibilityHelpers.swift
│   ├── HapticFeedback.swift
│   ├── KeyboardDismissModifier.swift
│   ├── PerformanceMonitor.swift
│   └── CrashReporter.swift
├── Resources/                 # Localization files
│   ├── en.lproj/
│   │   └── Localizable.strings
│   └── ar.lproj/
│       └── Localizable.strings
├── Assets.xcassets/           # App icons and colors
└── MizanFlow.xcdatamodeld/    # Core Data model
```

### Key Components

#### Models

- **WorkSchedule**: Represents a work schedule with days, interruptions, and vacation balance
- **SalaryBreakdown**: Contains all salary components (base, overtime, allowances, deductions)
- **BudgetEntry**: Represents income or expense entries with categories
- **Settings**: App-wide settings (language, theme, notifications)

#### ViewModels

- **WorkScheduleViewModel**: Manages schedule state and operations
- **SalaryViewModel**: Handles salary calculations and input
- **BudgetViewModel**: Manages budget entries and calculations
- **SettingsViewModel**: Controls app settings and preferences

#### Services

- **ScheduleEngine**: Core logic for generating and managing work schedules
- **SalaryEngine**: Calculates salary breakdowns based on schedule and inputs
- **HolidayService**: Detects and manages holidays (Eid, National Day, etc.)
- **BackupService**: Handles data export and import
- **DataPersistenceService**: Manages Core Data operations
- **SmartAlertService**: Provides intelligent notifications and alerts

## 🚀 Getting Started

### Requirements

- **Xcode**: Latest version (15.0 or later recommended)
- **iOS**: 18.4 or later
- **Device**: iPhone or iPad
- **Swift**: 5.0 or later

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd MizanFlow
   ```

2. **Open in Xcode**:
   ```bash
   open MizanFlow.xcodeproj
   ```

3. **Configure Signing**:
   - Select the project in Xcode
   - Go to "Signing & Capabilities"
   - Select your development team
   - Ensure the Bundle Identifier is set correctly

4. **Build and Run**:
   - Select your target device or simulator
   - Press `⌘R` to build and run

### First Launch

1. The app will start with a default schedule
2. Set your hitch start date in the Schedule view
3. Configure your base salary in the Salary view
4. Optionally set your preferred language and theme in Settings

## 📖 Usage Guide

### Setting Up Your Schedule

1. **Set Hitch Start Date**:
   - Open the Schedule tab
   - Tap "Set Hitch Start Date"
   - Select your first work day
   - The app will automatically generate the 14/7 pattern

2. **View Your Schedule**:
   - Navigate through months using the arrow buttons
   - Tap any day to see details
   - Different colors represent different day types

3. **Add Interruptions**:
   - Tap a day in your schedule
   - Select "Schedule Interruption"
   - Choose interruption type (Vacation, Training, Short Leave, Company Off)
   - Set start and end dates
   - The app will automatically reschedule your pattern

### Calculating Your Salary

1. **Enter Base Salary**:
   - Go to the Salary tab
   - Enter your monthly base salary

2. **Configure Deductions**:
   - Set your home loan percentage (25-50%)
   - Set your ESPP percentage (1-10%)
   - Add any custom deductions

3. **Add Overtime/ADL Hours**:
   - Enter overtime hours worked
   - Enter ADL hours if applicable
   - The app calculates pay automatically

4. **View Breakdown**:
   - See total allowances
   - See total deductions
   - View your net pay

### Tracking Your Budget

1. **Add Income**:
   - Go to the Budget tab
   - Tap "Add Entry"
   - Select "Is Income"
   - Enter amount and category
   - Save

2. **Add Expenses**:
   - Tap "Add Entry"
   - Leave "Is Income" unchecked
   - Enter amount and select category
   - Add optional notes
   - Save

3. **View Summary**:
   - See total income and expenses
   - View net balance
   - Check savings rate
   - Review category breakdown

### Changing Settings

1. **Language**:
   - Go to Settings
   - Tap "Language"
   - Select English or Arabic
   - App will restart to apply changes

2. **Theme**:
   - Go to Settings
   - Tap "Theme"
   - Choose Light, Dark, or System

3. **Notifications**:
   - Enable/disable notifications
   - Set low off days threshold
   - Receive smart alerts

## 🧪 Testing

The project includes unit tests and UI tests:

### Unit Tests

- **SalaryEngineTests**: Tests salary calculation logic
- **ValidationUtilitiesTests**: Tests input validation
- **MizanFlowTests**: General app tests

### UI Tests

- **ScheduleViewUITests**: Tests schedule view interactions
- **MizanFlowUITests**: General UI tests
- **MizanFlowUITestsLaunchTests**: Launch performance tests

### Running Tests

1. In Xcode, press `⌘U` to run all tests
2. Or use the Test Navigator (`⌘6`) to run specific tests

## 🔧 Development

### Code Style

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions focused and single-purpose

### Logging

The app uses the unified logging system (`os.Logger`):

```swift
AppLogger.general.info("Message")
AppLogger.coreData.error("Error message")
AppLogger.viewModel.debug("Debug info")
```

### Error Handling

- Use `AppError` enum for app-specific errors
- Log errors using `AppLogger`
- Provide user-friendly error messages
- Handle Core Data errors gracefully

### Performance

- Use `PerformanceMonitor` for performance tracking
- Implement debouncing for frequent saves
- Use background contexts for heavy Core Data operations
- Optimize SwiftUI view updates

## 📝 Localization

### Adding New Strings

1. Add the English string to `Resources/en.lproj/Localizable.strings`
2. Add the Arabic translation to `Resources/ar.lproj/Localizable.strings`
3. Use `NSLocalizedString()` in code:
   ```swift
   Text(NSLocalizedString("Key", comment: "Comment"))
   ```

### Adding New Languages

1. Create a new `.lproj` folder in `Resources/`
2. Copy `Localizable.strings` to the new folder
3. Translate all strings
4. Update `Settings.Language` enum to include the new language

## 🐛 Troubleshooting

### Common Issues

1. **Schedule not generating**:
   - Ensure hitch start date is set
   - Check that the date is valid

2. **Salary calculations incorrect**:
   - Verify base salary is entered
   - Check that percentages are within valid ranges

3. **Language not changing**:
   - Restart the app after changing language
   - Check that localization files are included in the project

4. **Data not persisting**:
   - Check Core Data model is correct
   - Verify DataPersistenceService is saving context

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Bu Saad**
- Created: May 10, 2025

## 🙏 Acknowledgments

- Built for shift workers in Saudi Arabia
- Designed to handle the 14/7 hitch pattern
- Supports Saudi-specific holidays and salary structures

## 🔮 Future Enhancements

Potential features for future versions:

- [ ] Cloud sync across devices
- [ ] Widget support for quick schedule view
- [ ] Apple Watch companion app
- [ ] Advanced analytics and reports
- [ ] Multiple schedule support
- [ ] Team/coworker schedule sharing
- [ ] Integration with calendar apps
- [ ] PDF export for salary slips
- [ ] More language support

---

**Note**: This README is a comprehensive guide. For specific technical questions or issues, please refer to the code comments or create an issue in the repository.

