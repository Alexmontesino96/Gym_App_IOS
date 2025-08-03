import Foundation
import CoreData

// MARK: - Core Data Manager
class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        // Crear modelo programáticamente
        let managedObjectModel = createManagedObjectModel()
        
        let container = NSPersistentContainer(name: "MessageCache", managedObjectModel: managedObjectModel)
        
        // Configurar el store
        let storeURL = getStoreURL()
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.type = NSSQLiteStoreType
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true
        
        container.persistentStoreDescriptions = [storeDescription]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("❌ Core Data failed to load: \(error.localizedDescription)")
                // En producción, podrías querer manejar esto más graciosamente
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            } else {
                print("✅ Core Data loaded successfully")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Core Data Model Creation
    private func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Create CachedMessageEntity
        let messageEntity = createMessageEntity()
        
        // Create ConversationSyncEntity
        let syncEntity = createSyncEntity()
        
        model.entities = [messageEntity, syncEntity]
        
        return model
    }
    
    private func createMessageEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CachedMessageEntity"
        entity.managedObjectClassName = "CachedMessageEntity"
        
        // Create attributes
        var properties: [NSPropertyDescription] = []
        
        // ID attribute (Primary Key)
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .stringAttributeType
        idAttribute.isOptional = false
        properties.append(idAttribute)
        
        // Conversation ID attribute (Index)
        let conversationIdAttribute = NSAttributeDescription()
        conversationIdAttribute.name = "conversationId"
        conversationIdAttribute.attributeType = .stringAttributeType
        conversationIdAttribute.isOptional = false
        properties.append(conversationIdAttribute)
        
        // Text attribute
        let textAttribute = NSAttributeDescription()
        textAttribute.name = "text"
        textAttribute.attributeType = .stringAttributeType
        textAttribute.isOptional = false
        properties.append(textAttribute)
        
        // Author ID attribute
        let authorIdAttribute = NSAttributeDescription()
        authorIdAttribute.name = "authorId"
        authorIdAttribute.attributeType = .stringAttributeType
        authorIdAttribute.isOptional = false
        properties.append(authorIdAttribute)
        
        // Author Name attribute
        let authorNameAttribute = NSAttributeDescription()
        authorNameAttribute.name = "authorName"
        authorNameAttribute.attributeType = .stringAttributeType
        authorNameAttribute.isOptional = false
        properties.append(authorNameAttribute)
        
        // Timestamp attribute (Index)
        let timestampAttribute = NSAttributeDescription()
        timestampAttribute.name = "timestamp"
        timestampAttribute.attributeType = .dateAttributeType
        timestampAttribute.isOptional = false
        properties.append(timestampAttribute)
        
        // Is From Current User attribute
        let isFromCurrentUserAttribute = NSAttributeDescription()
        isFromCurrentUserAttribute.name = "isFromCurrentUser"
        isFromCurrentUserAttribute.attributeType = .booleanAttributeType
        isFromCurrentUserAttribute.defaultValue = false
        properties.append(isFromCurrentUserAttribute)
        
        // Sync Status attribute
        let syncStatusAttribute = NSAttributeDescription()
        syncStatusAttribute.name = "syncStatus"
        syncStatusAttribute.attributeType = .stringAttributeType
        syncStatusAttribute.defaultValue = "synced"
        properties.append(syncStatusAttribute)
        
        // Is Read attribute
        let isReadAttribute = NSAttributeDescription()
        isReadAttribute.name = "isRead"
        isReadAttribute.attributeType = .booleanAttributeType
        isReadAttribute.defaultValue = false
        properties.append(isReadAttribute)
        
        // Created At attribute
        let createdAtAttribute = NSAttributeDescription()
        createdAtAttribute.name = "createdAt"
        createdAtAttribute.attributeType = .dateAttributeType
        createdAtAttribute.isOptional = true
        properties.append(createdAtAttribute)
        
        // Updated At attribute
        let updatedAtAttribute = NSAttributeDescription()
        updatedAtAttribute.name = "updatedAt"
        updatedAtAttribute.attributeType = .dateAttributeType
        updatedAtAttribute.isOptional = true
        properties.append(updatedAtAttribute)
        
        entity.properties = properties
        
        return entity
    }
    
    private func createSyncEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "ConversationSyncEntity"
        entity.managedObjectClassName = "ConversationSyncEntity"
        
        var properties: [NSPropertyDescription] = []
        
        // Conversation ID attribute (Primary Key)
        let conversationIdAttribute = NSAttributeDescription()
        conversationIdAttribute.name = "conversationId"
        conversationIdAttribute.attributeType = .stringAttributeType
        conversationIdAttribute.isOptional = false
        properties.append(conversationIdAttribute)
        
        // Last Sync Date attribute
        let lastSyncDateAttribute = NSAttributeDescription()
        lastSyncDateAttribute.name = "lastSyncDate"
        lastSyncDateAttribute.attributeType = .dateAttributeType
        lastSyncDateAttribute.isOptional = true
        properties.append(lastSyncDateAttribute)
        
        // Message Count attribute
        let messageCountAttribute = NSAttributeDescription()
        messageCountAttribute.name = "messageCount"
        messageCountAttribute.attributeType = .integer32AttributeType
        messageCountAttribute.defaultValue = 0
        properties.append(messageCountAttribute)
        
        // Created At attribute
        let createdAtAttribute = NSAttributeDescription()
        createdAtAttribute.name = "createdAt"
        createdAtAttribute.attributeType = .dateAttributeType
        createdAtAttribute.isOptional = true
        properties.append(createdAtAttribute)
        
        // Updated At attribute
        let updatedAtAttribute = NSAttributeDescription()
        updatedAtAttribute.name = "updatedAt"
        updatedAtAttribute.attributeType = .dateAttributeType
        updatedAtAttribute.isOptional = true
        properties.append(updatedAtAttribute)
        
        entity.properties = properties
        
        return entity
    }
    
    // MARK: - Store URL
    private func getStoreURL() -> URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let docURL = urls[urls.endIndex - 1]
        return docURL.appendingPathComponent("MessageCache.sqlite")
    }
    
    // MARK: - Core Data Operations
    func saveContext() {
        let context = persistentContainer.viewContext
        
        guard context.hasChanges else {
            return // No hay cambios, no hacer nada
        }
        
        do {
            // Verificar si hay cambios reales (no solo updatedAt)
            let insertedObjects = context.insertedObjects
            let updatedObjects = context.updatedObjects
            let deletedObjects = context.deletedObjects
            
            // Debug: mostrar qué está cambiando
            if !insertedObjects.isEmpty {
                print("📝 Core Data: \(insertedObjects.count) objetos insertados")
            }
            if !updatedObjects.isEmpty {
                print("📝 Core Data: \(updatedObjects.count) objetos actualizados")
                for obj in updatedObjects {
                    if let entity = obj as? CachedMessageEntity {
                        let changes = entity.changedValues()
                        print("  - Mensaje \(entity.id ?? "unknown"): \(changes.keys)")
                    }
                }
            }
            if !deletedObjects.isEmpty {
                print("📝 Core Data: \(deletedObjects.count) objetos eliminados")
            }
            
            try context.save()
            print("✅ Core Data guardado exitosamente")
            
        } catch let error as NSError {
            print("❌ Failed to save context: \(error)")
            print("❌ Error info: \(error.userInfo)")
            
            // En caso de error, intentar rollback
            context.rollback()
            print("🔄 Context rollback completado")
        }
    }
    
    func deleteAllData() {
        let entities = persistentContainer.managedObjectModel.entities
        
        for entity in entities {
            guard let entityName = entity.name else { continue }
            
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
            } catch {
                print("❌ Failed to delete \(entityName): \(error)")
            }
        }
        
        saveContext()
    }
}