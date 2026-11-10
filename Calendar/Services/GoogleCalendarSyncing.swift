import Foundation

/// Google Calendar API + outbox (A-アウトボックス).
@MainActor
protocol GoogleCalendarSyncing: AnyObject {
    var isSignedIn: Bool { get }
    var isSyncing: Bool { get }
    var lastError: String? { get }

    func signInIfNeeded() async throws
    func signIn() async throws
    func signOut()
    func syncAllCalendars() async throws
    /// 表示中の月が未取得なら、その周辺を `events.list` で取得する。
    func ensureSynced(for visibleMonth: YearMonth) async
    func enqueueSave(draft: EventDraft) async
    func enqueueUpdate(draft: EventDraft) async
    func enqueueDelete(calendarId: String, googleEventId: String) async
}

final class StubGoogleCalendarSync: GoogleCalendarSyncing {
    var isSignedIn = false
    var isSyncing = false
    var lastError: String?

    func signInIfNeeded() async throws {}
    func signIn() async throws {}
    func signOut() {}
    func syncAllCalendars() async throws {}
    func ensureSynced(for visibleMonth: YearMonth) async {}
    func enqueueSave(draft: EventDraft) async {}
    func enqueueUpdate(draft: EventDraft) async {}
    func enqueueDelete(calendarId: String, googleEventId: String) async {}
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
    var localEventId: String?
    var googleEventId: String?
    var calendarId: String
    var title: String
    var isAllDay: Bool
    var startISO8601: String
    var endISO8601: String
    var selectedDays: [LocalDay]
    var recurrence: RecurrenceRule
    var reminderMinutes: [Int]
    var location: String?
    var url: String?
    var notes: String?
}
