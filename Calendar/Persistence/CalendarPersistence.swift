import Foundation
import SwiftData

enum CalendarPersistence {
    static let schema = Schema([
        StoredCalendarEvent.self,
        StoredSubscribedCalendar.self,
        StoredOutboxItem.self,
    ])

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("ModelContainer の作成に失敗: \(error)")
        }
    }

    static func makePreviewContainer() -> ModelContainer {
        makeContainer(inMemory: true)
    }
}
