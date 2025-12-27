import Foundation
import CoreData
import os

@MainActor
class DataPersistenceService {
    static let shared = DataPersistenceService()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "MizanFlow")
        // Configure store description before loading stores
        let description = NSPersistentStoreDescription()
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { [weak self] description, error in
            if let error = error {
                AppLogger.coreData.critical("Unable to load persistent stores: \(String(describing: error), privacy: .public)")
                // Attempt fallback to in-memory store
                let fallbackDescription = NSPersistentStoreDescription()
                fallbackDescription.url = URL(fileURLWithPath: "/dev/null")
                fallbackDescription.shouldMigrateStoreAutomatically = true
                fallbackDescription.shouldInferMappingModelAutomatically = true
                container.persistentStoreDescriptions = [fallbackDescription]
                container.loadPersistentStores { fallbackDescription, fallbackError in
                    guard fallbackError == nil else {
                        AppLogger.coreData.critical("Unable to load fallback in-memory persistent store: \(String(describing: fallbackError), privacy: .public)")
                        return
                    }
                }
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    var backgroundContext: NSManagedObjectContext {
        persistentContainer.newBackgroundContext()
    }
    
    // loadPersistentStore no longer needed; configuration moved into lazy container
    
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let error = error as NSError
                AppLogger.coreData.error("Failed to save context: \(String(describing: error), privacy: .public) | info: \(String(describing: error.userInfo), privacy: .public)")
                // Attempt to rollback changes
                context.rollback()
            }
        }
    }
    
    // MARK: - Schedule Operations
    
    func saveSchedule(_ schedule: WorkSchedule) {
        let scheduleEntity = ScheduleEntity(context: context)
        scheduleEntity.id = schedule.id
        scheduleEntity.startDate = schedule.startDate
        scheduleEntity.endDate = schedule.endDate
        scheduleEntity.isInterrupted = schedule.isInterrupted
        scheduleEntity.interruptionStart = schedule.interruptionStart
        scheduleEntity.interruptionEnd = schedule.interruptionEnd
        scheduleEntity.interruptionType = schedule.interruptionType?.rawValue
        scheduleEntity.preferredReturnDay = Int16(schedule.preferredReturnDay?.rawValue ?? 0)
        scheduleEntity.vacationBalance = Int16(schedule.vacationBalance)
        scheduleEntity.hitchStartDate = schedule.hitchStartDate
        scheduleEntity.manuallyAdjusted = schedule.manuallyAdjusted
        
        // Save schedule days
        for day in schedule.days {
            let dayEntity = ScheduleDayEntity(context: context)
            dayEntity.id = day.id
            dayEntity.date = day.date
            dayEntity.type = day.type.rawValue
            dayEntity.isOverride = day.isOverride
            dayEntity.notes = day.notes
            dayEntity.overtimeHours = day.overtimeHours ?? 0
            dayEntity.isInHitch = day.isInHitch
            dayEntity.hasIcon = day.hasIcon
            dayEntity.iconName = day.iconName
            dayEntity.schedule = scheduleEntity
        }
        
        saveContext()
    }
    
    func saveScheduleInBackground(_ schedule: WorkSchedule) {
        let bgContext = self.backgroundContext
        bgContext.perform { [weak self] in
            guard self != nil else { return }
            let scheduleEntity = ScheduleEntity(context: bgContext)
            scheduleEntity.id = schedule.id
            scheduleEntity.startDate = schedule.startDate
            scheduleEntity.endDate = schedule.endDate
            scheduleEntity.isInterrupted = schedule.isInterrupted
            scheduleEntity.interruptionStart = schedule.interruptionStart
            scheduleEntity.interruptionEnd = schedule.interruptionEnd
            scheduleEntity.interruptionType = schedule.interruptionType?.rawValue
            scheduleEntity.preferredReturnDay = Int16(schedule.preferredReturnDay?.rawValue ?? 0)
            scheduleEntity.vacationBalance = Int16(schedule.vacationBalance)
            scheduleEntity.hitchStartDate = schedule.hitchStartDate
            scheduleEntity.manuallyAdjusted = schedule.manuallyAdjusted
            
            for day in schedule.days {
                let dayEntity = ScheduleDayEntity(context: bgContext)
                dayEntity.id = day.id
                dayEntity.date = day.date
                dayEntity.type = day.type.rawValue
                dayEntity.isOverride = day.isOverride
                dayEntity.notes = day.notes
                dayEntity.overtimeHours = day.overtimeHours ?? 0
                dayEntity.isInHitch = day.isInHitch
                dayEntity.hasIcon = day.hasIcon
                dayEntity.iconName = day.iconName
                dayEntity.schedule = scheduleEntity
            }
            
            do {
                if bgContext.hasChanges {
                    try bgContext.save()
                    AppLogger.coreData.info("Successfully saved schedule in background context for schedule id \(schedule.id.uuidString, privacy: .public)")
                }
            } catch {
                let nsError = error as NSError
                AppLogger.coreData.error("Failed to save schedule in background context: \(String(describing: nsError), privacy: .public) | info: \(String(describing: nsError.userInfo), privacy: .public)")
                bgContext.rollback()
            }
        }
    }
    
    func loadSchedule(id: UUID) -> WorkSchedule? {
        let request: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        request.includesPropertyValues = true
        request.returnsObjectsAsFaults = false
        request.relationshipKeyPathsForPrefetching = ["days"]
        
        do {
            let results = try context.fetch(request)
            guard let scheduleEntity = results.first else { return nil }
            
            var schedule = convertToWorkSchedule(from: scheduleEntity)
            
            // Load hitch start date from Core Data
            if let hitchStartDate = scheduleEntity.hitchStartDate {
                schedule.hitchStartDate = hitchStartDate
            }
            
            // Load vacation balance from Core Data
            schedule.vacationBalance = Int(scheduleEntity.vacationBalance)
            
            return schedule
        } catch {
            AppLogger.coreData.error("Error loading schedule: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
    
    func loadLatestSchedule() -> WorkSchedule? {
        let request: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        request.fetchLimit = 1
        request.includesPropertyValues = true
        request.returnsObjectsAsFaults = false
        request.relationshipKeyPathsForPrefetching = ["days"]
        
        do {
            let results = try context.fetch(request)
            guard let scheduleEntity = results.first else { return nil }
            
            var schedule = convertToWorkSchedule(from: scheduleEntity)
            
            // Load hitch start date from Core Data
            if let hitchStartDate = scheduleEntity.hitchStartDate {
                schedule.hitchStartDate = hitchStartDate
            }
            
            // Load vacation balance from Core Data
            schedule.vacationBalance = Int(scheduleEntity.vacationBalance)
            
            // Recompute interruption data if needed
            recomputeInterruptionDataIfNeeded(&schedule)
            
            return schedule
        } catch {
            AppLogger.coreData.error("Error loading latest schedule: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
    
    // MARK: - Enhanced Data Recomputation
    
    func recomputeInterruptionDataIfNeeded(_ schedule: inout WorkSchedule) {
        // Only recompute if schedule is interrupted and we have interruption data
        guard schedule.isInterrupted,
              let interruptionStart = schedule.interruptionStart else {
            return
        }
        
        // Recompute using the new correct formula
        let (workedDays, earnedDays) = ScheduleEngine.shared.calculateWorkedAndEarnedDaysBeforeInterruption(
            schedule,
            interruptionStart: interruptionStart
        )
        
        // Update stored values if they differ (indicates old calculation)
        if schedule.workedDaysBeforeInterruption != workedDays ||
           schedule.earnedOffDaysBeforeInterruption != earnedDays {
            
            schedule.workedDaysBeforeInterruption = workedDays
            schedule.earnedOffDaysBeforeInterruption = earnedDays
            
            // Recalculate vacation usage with correct earned days
            if let interruptionEnd = schedule.interruptionEnd {
                let vacationUsed = ScheduleEngine.shared.calculateVacationDaysUsed(
                    schedule,
                    startDate: interruptionStart,
                    endDate: interruptionEnd
                )
                schedule.vacationBalance = max(0, schedule.vacationBalance + vacationUsed)
            }
            
            // Save the corrected data
            saveSchedule(schedule)
        }
    }
    
    private func convertToWorkSchedule(from entity: ScheduleEntity) -> WorkSchedule {
        var schedule = WorkSchedule(startDate: entity.startDate ?? Date())
        schedule.id = entity.id ?? UUID()
        schedule.endDate = entity.endDate ?? Date()
        schedule.isInterrupted = entity.isInterrupted
        schedule.interruptionStart = entity.interruptionStart
        schedule.interruptionEnd = entity.interruptionEnd
        schedule.interruptionType = entity.interruptionType.flatMap { WorkSchedule.InterruptionType(rawValue: $0) }
        schedule.preferredReturnDay = entity.preferredReturnDay > 0 ? WorkSchedule.Weekday(rawValue: Int(entity.preferredReturnDay)) : nil
        
        if let days = entity.days as? Set<ScheduleDayEntity> {
            // Sort days by date for consistent ordering
            schedule.days = days.sorted(by: { ($0.date ?? Date()) < ($1.date ?? Date()) }).map { dayEntity in
                WorkSchedule.ScheduleDay(
                    id: dayEntity.id ?? UUID(),
                    date: dayEntity.date ?? Date(),
                    type: DayType(rawValue: dayEntity.type ?? "") ?? .workday,
                    isHoliday: false, // Default to false since CoreData doesn't have this field
                    isOverride: dayEntity.isOverride,
                    notes: dayEntity.notes,
                    overtimeHours: dayEntity.overtimeHours,
                    isInHitch: dayEntity.isInHitch,
                    hasIcon: dayEntity.hasIcon,
                    iconName: dayEntity.iconName
                )
            }
        }
        
        return schedule
    }
    
    // MARK: - Salary Operations
    
    func saveSalaryBreakdown(_ breakdown: SalaryBreakdown) {
        let breakdownEntity = SalaryBreakdownEntity(context: context)
        breakdownEntity.id = breakdown.id
        breakdownEntity.baseSalary = breakdown.baseSalary
        breakdownEntity.month = breakdown.month
        breakdownEntity.overtimeHours = breakdown.overtimeHours
        breakdownEntity.adlHours = breakdown.adlHours
        breakdownEntity.specialOperationsPercentage = breakdown.specialOperationsPercentage
        breakdownEntity.homeLoanPercentage = breakdown.homeLoanPercentage
        breakdownEntity.esppPercentage = breakdown.esppPercentage
        
        // Save additional income
        for income in breakdown.additionalIncome {
            let incomeEntity = AdditionalEntryEntity(context: context)
            incomeEntity.id = income.id
            incomeEntity.amount = income.amount
            incomeEntity.entryDescription = income.entryDescription
            incomeEntity.isIncome = true
            incomeEntity.notes = income.notes
            incomeEntity.salaryBreakdown = breakdownEntity
        }
        
        // Save custom deductions
        for deduction in breakdown.customDeductions {
            let deductionEntity = AdditionalEntryEntity(context: context)
            deductionEntity.id = deduction.id
            deductionEntity.amount = deduction.amount
            deductionEntity.entryDescription = deduction.entryDescription
            deductionEntity.isIncome = false
            deductionEntity.notes = deduction.notes
            deductionEntity.salaryBreakdown = breakdownEntity
        }
        
        saveContext()
    }
    
    func loadSalaryBreakdown(id: UUID) -> SalaryBreakdown? {
        let request: NSFetchRequest<SalaryBreakdownEntity> = SalaryBreakdownEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        request.includesPropertyValues = true
        request.returnsObjectsAsFaults = false
        request.relationshipKeyPathsForPrefetching = ["entries"]
        
        do {
            let results = try context.fetch(request)
            guard let breakdownEntity = results.first else { return nil }
            
            return convertToSalaryBreakdown(from: breakdownEntity)
        } catch {
            AppLogger.coreData.error("Error loading salary breakdown: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
    
    private func convertToSalaryBreakdown(from entity: SalaryBreakdownEntity) -> SalaryBreakdown {
        var breakdown = SalaryBreakdown(baseSalary: entity.baseSalary, month: entity.month ?? Date())
        breakdown.id = entity.id ?? UUID()
        breakdown.overtimeHours = entity.overtimeHours
        breakdown.adlHours = entity.adlHours
        breakdown.specialOperationsPercentage = entity.specialOperationsPercentage
        breakdown.homeLoanPercentage = entity.homeLoanPercentage
        breakdown.esppPercentage = entity.esppPercentage
        
        if let entries = entity.entries as? Set<AdditionalEntryEntity> {
            for entry in entries {
                let additionalEntry = SalaryBreakdown.AdditionalEntry(
                    id: entry.id ?? UUID(),
                    amount: entry.amount,
                    entryDescription: entry.entryDescription ?? "",
                    isIncome: entry.isIncome,
                    notes: entry.notes
                )
                
                if entry.isIncome {
                    breakdown.additionalIncome.append(additionalEntry)
                } else {
                    breakdown.customDeductions.append(additionalEntry)
                }
            }
        }
        
        return breakdown
    }
} 

