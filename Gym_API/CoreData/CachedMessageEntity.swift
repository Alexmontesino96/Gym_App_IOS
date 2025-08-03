import Foundation
import CoreData

// MARK: - Cached Message Entity
@objc(CachedMessageEntity)
public class CachedMessageEntity: NSManagedObject {
    
    static func fetchRequest() -> NSFetchRequest<CachedMessageEntity> {
        return NSFetchRequest<CachedMessageEntity>(entityName: "CachedMessageEntity")
    }
    
    @NSManaged public var id: String?
    @NSManaged public var conversationId: String?
    @NSManaged public var text: String?
    @NSManaged public var authorId: String?
    @NSManaged public var authorName: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var isFromCurrentUser: Bool
    @NSManaged public var syncStatus: String?
    @NSManaged public var isRead: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        createdAt = now
        updatedAt = now
    }
    
    // Método manual para actualizar updatedAt cuando sea necesario
    public func markAsUpdated() {
        updatedAt = Date()
    }
}

// MARK: - Conversation Sync Entity
@objc(ConversationSyncEntity)
public class ConversationSyncEntity: NSManagedObject {
    
    static func fetchRequest() -> NSFetchRequest<ConversationSyncEntity> {
        return NSFetchRequest<ConversationSyncEntity>(entityName: "ConversationSyncEntity")
    }
    
    @NSManaged public var conversationId: String?
    @NSManaged public var lastSyncDate: Date?
    @NSManaged public var messageCount: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        createdAt = now
        updatedAt = now
        messageCount = 0
    }
    
    // Método manual para actualizar updatedAt cuando sea necesario
    public func markAsUpdated() {
        updatedAt = Date()
    }
}