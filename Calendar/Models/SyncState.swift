import Foundation

enum SyncState: String, Codable {
    case synced
    case pendingCreate
    case pendingUpdate
    case pendingDelete
}
