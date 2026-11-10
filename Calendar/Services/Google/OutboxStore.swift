import Foundation
import SwiftData

enum OutboxStore {
    private static let legacyFileName = "google_sync_outbox.json"

    private static var context: ModelContext?

    private static var legacyFileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(legacyFileName)
    }

    static func configure(context: ModelContext) {
        self.context = context
        migrateLegacyJSONIfNeeded(into: context)
    }

    static func load() -> [SyncOutboxItem] {
        guard let context else { return [] }
        let descriptor = FetchDescriptor<StoredOutboxItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.compactMap { $0.toSyncOutboxItem() }
    }

    static func save(_ items: [SyncOutboxItem]) {
        replaceAll(items)
    }

    static func append(_ item: SyncOutboxItem) {
        guard let context else { return }
        if let stored = try? StoredOutboxItem(from: item) {
            context.insert(stored)
            try? context.save()
        }
    }

    static func replaceAll(_ items: [SyncOutboxItem]) {
        guard let context else { return }
        if let existing = try? context.fetch(FetchDescriptor<StoredOutboxItem>()) {
            for row in existing {
                context.delete(row)
            }
        }
        for item in items {
            if let stored = try? StoredOutboxItem(from: item) {
                context.insert(stored)
            }
        }
        try? context.save()
    }

    private static func migrateLegacyJSONIfNeeded(into context: ModelContext) {
        let count = (try? context.fetch(FetchDescriptor<StoredOutboxItem>()))?.count ?? 0
        guard count == 0 else { return }
        guard let data = try? Data(contentsOf: legacyFileURL) else { return }
        let legacy = (try? JSONDecoder().decode([SyncOutboxItem].self, from: data)) ?? []
        guard !legacy.isEmpty else { return }
        for item in legacy {
            if let stored = try? StoredOutboxItem(from: item) {
                context.insert(stored)
            }
        }
        try? context.save()
        try? FileManager.default.removeItem(at: legacyFileURL)
    }
}
