import Foundation

/// Google Calendar API + outbox (A-アウトボックス) — implementation TBD.
protocol GoogleCalendarSyncing: Sendable {
    func signInIfNeeded() async throws
    func syncAllCalendars() async throws
    func enqueueSave(draft: EventDraft) async
}

final class StubGoogleCalendarSync: GoogleCalendarSyncing {
    func signInIfNeeded() async throws {}

    func syncAllCalendars() async throws {}

    func enqueueSave(draft: EventDraft) async {
        // Outbox placeholder: push when online.
    }
}

/// Per-calendar sync token and pull/push pipelines.
struct CalendarSyncPipeline {
    var calendarId: String
    var syncToken: String?
    var outbox: [SyncOutboxItem]
}

struct SyncOutboxItem: Identifiable, Codable {
    var id: UUID
    var calendarId: String
    var operation: OutboxOperation
    var createdAt: Date
}

enum OutboxOperation: Codable {
    case insert(EventDraftPayload)
    case update(EventDraftPayload)
    case delete(googleEventId: String)
}

struct EventDraftPayload: Codable {
    var title: String
    var isAllDay: Bool
    var startISO8601: String
    var endISO8601: String
    var selectedDays: [LocalDay]
    var recurrenceRRULE: String?
    var location: String?
    var url: String?
    var notes: String?
}
