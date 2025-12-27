//
//  Persistence.swift
//  MizanFlow
//
//  Created by Bu Saad on 10/05/2025.
//

import CoreData
import os

struct PersistenceController {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MizanFlow", category: "CoreData")

    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        // Sample data can be added here if needed
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            result.logger.error("Preview data creation failed: \(String(describing: nsError), privacy: .public)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MizanFlow")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Enable automatic merging of changes from parent contexts
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Configure merge policy
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Load persistent stores
        let logger = self.logger
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                // Handle different types of errors
                switch error.code {
                case NSPersistentStoreIncompatibleVersionHashError:
                    logger.warning("Store version mismatch. Attempting migration…")
                    PersistenceController.shared.handleStoreMigration()
                case NSPersistentStoreIncompleteSaveError:
                    logger.warning("Incomplete save. Attempting recovery…")
                    PersistenceController.shared.handleIncompleteSave()
                case NSPersistentStoreSaveConflictsError:
                    logger.warning("Save conflicts detected. Resolving…")
                    PersistenceController.shared.handleSaveConflicts()
                default:
                    logger.error("Core Data store loading failed: \(error.localizedDescription, privacy: .public) | info: \(String(describing: error.userInfo), privacy: .public)")
                }
            }
        }
    }
    
    // MARK: - Error Handling Methods
    
    func handleStoreMigration() {
        logger.warning("Store version mismatch detected. Attempting automatic migration...")
        
        // Core Data will attempt automatic migration if shouldMigrateStoreAutomatically is true
        // If automatic migration fails, we would need to implement manual migration
        // For now, we rely on Core Data's automatic migration capabilities
        
        // In a production app, you would:
        // 1. Check the current model version
        // 2. Create a migration mapping model if needed
        // 3. Perform the migration with progress tracking
        // 4. Handle migration errors gracefully
        
        logger.notice("Automatic migration will be attempted by Core Data")
    }
    
    func handleIncompleteSave() {
        logger.warning("Incomplete save detected. Attempting recovery...")
        
        let context = container.viewContext
        let logger = self.logger
        
        // Try to save again after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                if context.hasChanges {
                    try context.save()
                    logger.info("Successfully recovered from incomplete save")
                }
            } catch {
                logger.error("Recovery failed, rolling back changes: \(String(describing: error), privacy: .public)")
                context.rollback()
            }
        }
    }
    
    func handleSaveConflicts() {
        logger.warning("Save conflicts detected. Resolving with merge policy...")
        
        let context = container.viewContext
        
        // The merge policy (NSMergeByPropertyObjectTrumpMergePolicy) should handle most conflicts
        // For more complex conflicts, we could:
        // 1. Detect which objects have conflicts
        // 2. Present user with conflict resolution options
        // 3. Apply user's preferred resolution strategy
        
        // For now, rely on the configured merge policy
        do {
            if context.hasChanges {
                try context.save()
                logger.info("Conflicts resolved using merge policy")
            }
        } catch {
            logger.error("Conflict resolution failed: \(String(describing: error), privacy: .public)")
            context.rollback()
        }
    }
    
    // MARK: - Context Management
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                logger.debug("Successfully saved context")
            } catch {
                let nsError = error as NSError
                logger.error("Failed to save context: \(String(describing: nsError), privacy: .public) | info: \(String(describing: nsError.userInfo), privacy: .public)")
                
                // Attempt to rollback changes
                context.rollback()
            }
        }
    }
    
    // MARK: - Cache Management
    
    func wipeAllData() {
        let context = container.viewContext
        
        // Get all entity names from the model
        let model = container.managedObjectModel
        
        // Delete all objects for each entity
        for entity in model.entities {
            guard let entityName = entity.name else { continue }
            
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(batchDeleteRequest)
                logger.debug("Successfully deleted all \(entityName, privacy: .public) objects")
            } catch {
                logger.error("Failed to delete \(entityName, privacy: .public) objects: \(String(describing: error), privacy: .public)")
            }
        }
        
        // Save the context after all deletions
        do {
            try context.save()
            logger.debug("Successfully saved context after data wipe")
        } catch {
            logger.error("Failed to save context after data wipe: \(String(describing: error), privacy: .public)")
            context.rollback()
        }
    }
    
    // MARK: - Background Task Management
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            block(context)
            
            if context.hasChanges {
                do {
                    try context.save()
                    logger.debug("Successfully saved background context")
                } catch {
                    let nsError = error as NSError
                    logger.error("Failed to save background context: \(String(describing: nsError), privacy: .public) | info: \(String(describing: nsError.userInfo), privacy: .public)")
                    context.rollback()
                }
            }
        }
    }
}

