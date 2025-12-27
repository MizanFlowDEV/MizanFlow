import Foundation
import CoreData
import os

/// Service for backing up and exporting app data
@MainActor
class BackupService {
    static let shared = BackupService()
    
    private let logger = AppLogger.general
    private let dataService = DataPersistenceService.shared
    
    private init() {}
    
    // MARK: - Export Functions
    
    /// Exports all schedule data to JSON
    func exportSchedules() throws -> Data {
        let request: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        
        let schedules = try dataService.context.fetch(request)
        
        let exportData = schedules.map { entity -> [String: Any] in
            var scheduleDict: [String: Any] = [:]
            scheduleDict["id"] = entity.id?.uuidString
            scheduleDict["startDate"] = entity.startDate?.timeIntervalSince1970
            scheduleDict["endDate"] = entity.endDate?.timeIntervalSince1970
            scheduleDict["isInterrupted"] = entity.isInterrupted
            scheduleDict["interruptionStart"] = entity.interruptionStart?.timeIntervalSince1970
            scheduleDict["interruptionEnd"] = entity.interruptionEnd?.timeIntervalSince1970
            scheduleDict["interruptionType"] = entity.interruptionType
            scheduleDict["vacationBalance"] = entity.vacationBalance
            scheduleDict["hitchStartDate"] = entity.hitchStartDate?.timeIntervalSince1970
            
            if let days = entity.days as? Set<ScheduleDayEntity> {
                scheduleDict["days"] = days.map { day -> [String: Any] in
                    [
                        "id": day.id?.uuidString ?? "",
                        "date": day.date?.timeIntervalSince1970 ?? 0,
                        "type": day.type ?? "",
                        "isOverride": day.isOverride,
                        "notes": day.notes ?? "",
                        "overtimeHours": day.overtimeHours,
                        "isInHitch": day.isInHitch
                    ]
                }
            }
            
            return scheduleDict
        }
        
        return try JSONSerialization.data(withJSONObject: ["schedules": exportData], options: .prettyPrinted)
    }
    
    /// Exports all salary breakdowns to JSON
    func exportSalaryBreakdowns() throws -> Data {
        let request: NSFetchRequest<SalaryBreakdownEntity> = SalaryBreakdownEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "month", ascending: false)]
        
        let breakdowns = try dataService.context.fetch(request)
        
        let exportData = breakdowns.map { entity -> [String: Any] in
            var breakdownDict: [String: Any] = [:]
            breakdownDict["id"] = entity.id?.uuidString
            breakdownDict["baseSalary"] = entity.baseSalary
            breakdownDict["month"] = entity.month?.timeIntervalSince1970
            breakdownDict["overtimeHours"] = entity.overtimeHours
            breakdownDict["adlHours"] = entity.adlHours
            breakdownDict["specialOperationsPercentage"] = entity.specialOperationsPercentage
            breakdownDict["homeLoanPercentage"] = entity.homeLoanPercentage
            breakdownDict["esppPercentage"] = entity.esppPercentage
            
            if let entries = entity.entries as? Set<AdditionalEntryEntity> {
                breakdownDict["entries"] = entries.map { entry -> [String: Any] in
                    [
                        "id": entry.id?.uuidString ?? "",
                        "amount": entry.amount,
                        "description": entry.entryDescription ?? "",
                        "isIncome": entry.isIncome,
                        "notes": entry.notes ?? ""
                    ]
                }
            }
            
            return breakdownDict
        }
        
        return try JSONSerialization.data(withJSONObject: ["salaryBreakdowns": exportData], options: .prettyPrinted)
    }
    
    /// Exports all app data to a single JSON file
    func exportAllData() throws -> Data {
        let schedules = try exportSchedules()
        let salaryBreakdowns = try exportSalaryBreakdowns()
        
        let schedulesDict = try JSONSerialization.jsonObject(with: schedules) as? [String: Any] ?? [:]
        let salaryDict = try JSONSerialization.jsonObject(with: salaryBreakdowns) as? [String: Any] ?? [:]
        
        let allData: [String: Any] = [
            "version": "1.0",
            "exportDate": Date().timeIntervalSince1970,
            "schedules": schedulesDict["schedules"] ?? [],
            "salaryBreakdowns": salaryDict["salaryBreakdowns"] ?? []
        ]
        
        return try JSONSerialization.data(withJSONObject: allData, options: .prettyPrinted)
    }
    
    // MARK: - Import Functions
    
    /// Imports data from JSON (with validation)
    func importData(from data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError.fileError("Invalid JSON format")
        }
        
        // Validate version if present
        if let version = json["version"] as? String, version != "1.0" {
            logger.warning("Importing data from version \(version, privacy: .public), which may not be compatible")
        }
        
        // Import schedules
        if let schedules = json["schedules"] as? [[String: Any]] {
            try importSchedules(schedules)
        }
        
        // Import salary breakdowns
        if let breakdowns = json["salaryBreakdowns"] as? [[String: Any]] {
            try importSalaryBreakdowns(breakdowns)
        }
        
        // Save context
        dataService.saveContext()
        
        logger.info("Successfully imported data")
    }
    
    private func importSchedules(_ schedules: [[String: Any]]) throws {
        let context = dataService.context
        
        for scheduleDict in schedules {
            guard let idString = scheduleDict["id"] as? String,
                  let id = UUID(uuidString: idString) else {
                continue
            }
            
            // Check if schedule already exists
            let request: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            if try context.fetch(request).first != nil {
                continue // Skip existing schedules
            }
            
            let entity = ScheduleEntity(context: context)
            entity.id = id
            entity.startDate = (scheduleDict["startDate"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
            entity.endDate = (scheduleDict["endDate"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
            entity.isInterrupted = scheduleDict["isInterrupted"] as? Bool ?? false
            entity.interruptionStart = (scheduleDict["interruptionStart"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
            entity.interruptionEnd = (scheduleDict["interruptionEnd"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
            entity.interruptionType = scheduleDict["interruptionType"] as? String
            entity.vacationBalance = Int16(scheduleDict["vacationBalance"] as? Int ?? 30)
            entity.hitchStartDate = (scheduleDict["hitchStartDate"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
            
            // Import days
            if let days = scheduleDict["days"] as? [[String: Any]] {
                for dayDict in days {
                    let dayEntity = ScheduleDayEntity(context: context)
                    dayEntity.id = (dayDict["id"] as? String).flatMap { UUID(uuidString: $0) }
                    dayEntity.date = (dayDict["date"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
                    dayEntity.type = dayDict["type"] as? String
                    dayEntity.isOverride = dayDict["isOverride"] as? Bool ?? false
                    dayEntity.notes = dayDict["notes"] as? String
                    dayEntity.overtimeHours = dayDict["overtimeHours"] as? Double ?? 0
                    dayEntity.isInHitch = dayDict["isInHitch"] as? Bool ?? false
                    dayEntity.schedule = entity
                }
            }
        }
    }
    
    private func importSalaryBreakdowns(_ breakdowns: [[String: Any]]) throws {
        let context = dataService.context
        
        for breakdownDict in breakdowns {
            guard let idString = breakdownDict["id"] as? String,
                  let id = UUID(uuidString: idString) else {
                continue
            }
            
            // Check if breakdown already exists
            let request: NSFetchRequest<SalaryBreakdownEntity> = SalaryBreakdownEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            if try context.fetch(request).first != nil {
                continue // Skip existing breakdowns
            }
            
            let entity = SalaryBreakdownEntity(context: context)
            entity.id = id
            entity.baseSalary = breakdownDict["baseSalary"] as? Double ?? 0
            entity.month = (breakdownDict["month"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
            entity.overtimeHours = breakdownDict["overtimeHours"] as? Double ?? 0
            entity.adlHours = breakdownDict["adlHours"] as? Double ?? 0
            entity.specialOperationsPercentage = breakdownDict["specialOperationsPercentage"] as? Double ?? 5
            entity.homeLoanPercentage = breakdownDict["homeLoanPercentage"] as? Double ?? 0
            entity.esppPercentage = breakdownDict["esppPercentage"] as? Double ?? 0
            
            // Import entries
            if let entries = breakdownDict["entries"] as? [[String: Any]] {
                for entryDict in entries {
                    let entryEntity = AdditionalEntryEntity(context: context)
                    entryEntity.id = (entryDict["id"] as? String).flatMap { UUID(uuidString: $0) }
                    entryEntity.amount = entryDict["amount"] as? Double ?? 0
                    entryEntity.entryDescription = entryDict["description"] as? String
                    entryEntity.isIncome = entryDict["isIncome"] as? Bool ?? false
                    entryEntity.notes = entryDict["notes"] as? String
                    entryEntity.salaryBreakdown = entity
                }
            }
        }
    }
    
    // MARK: - Backup Before Operations
    
    /// Creates a backup before a major operation
    func createBackup() throws -> URL {
        let backupData = try exportAllData()
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let backupURL = documentsPath.appendingPathComponent("backup_\(Date().timeIntervalSince1970).json")
        
        try backupData.write(to: backupURL)
        logger.info("Backup created at: \(backupURL.path, privacy: .public)")
        
        return backupURL
    }
}



