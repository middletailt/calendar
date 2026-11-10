import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class GoogleCalendarSyncService: GoogleCalendarSyncing {
    nonisolated init() {}

    private let oauth = GoogleOAuthClient.shared
    private let api = GoogleCalendarAPIClient()

    private weak var eventStore: EventStore?
    private weak var calendarStore: SubscribedCalendarStore?
    private var onEventsUpdated: (() -> Void)?

    /// 初回同期・`syncAll` 時の中心 ±1 ヶ月（計 3 ヶ月）
    private let initialWindowRadiusMonths = 1
    /// 月表示の追撃取得も同じ幅
    private let onDemandWindowRadiusMonths = 1

    private var ensureVisibleMonthTask: Task<Void, Never>?

    var isSyncing = false
    var lastError: String?
    var signedInAccountDescription = ""

    var isSignedIn: Bool { oauth.isSignedIn }

    func configure(eventStore: EventStore, calendarStore: SubscribedCalendarStore, onEventsUpdated: (() -> Void)? = nil) {
        self.eventStore = eventStore
        self.calendarStore = calendarStore
        self.onEventsUpdated = onEventsUpdated
    }

    func signInIfNeeded() async throws {
        guard !isSignedIn else { return }
        try await signIn()
    }

    func signIn() async throws {
        _ = try await oauth.signIn()
        signedInAccountDescription = "Google に接続済み"
        lastError = nil
        try await syncAllCalendars()
    }

    func signOut() {
        do {
            try oauth.signOut()
        } catch {
            lastError = error.localizedDescription
        }
        signedInAccountDescription = ""
        let ids = calendarStore?.calendars.map(\.id) ?? []
        calendarStore?.replace(with: [])
        eventStore?.clearAll()
        SyncTokenStore.clearAll(for: ids)
        SyncedMonthStore.clearAll(for: ids)
        OutboxStore.replaceAll([])
    }

    /// 表示月が未取得なら、その月を中心に 3 ヶ月分を取得する。
    func ensureSynced(for visibleMonth: YearMonth) async {
        guard isSignedIn, let eventStore, let calendarStore else { return }
        ensureVisibleMonthTask?.cancel()
        let task = Task {
            do {
                let token = try await oauth.validAccessToken()
                let targets = calendarStore.calendars.filter { $0.isVisible || $0.isJapaneseHolidayCalendar }
                var updated = false
                for cal in targets {
                    if SyncedMonthStore.isRangeFullySynced(
                        calendarId: cal.id,
                        center: visibleMonth,
                        radiusMonths: onDemandWindowRadiusMonths
                    ) {
                        continue
                    }
                    try await pullMonthWindow(
                        calendarId: cal.id,
                        center: visibleMonth,
                        radiusMonths: onDemandWindowRadiusMonths,
                        token: token,
                        eventStore: eventStore,
                        calendarStore: calendarStore
                    )
                    updated = true
                }
                if updated, !Task.isCancelled {
                    lastError = nil
                    onEventsUpdated?()
                }
            } catch {
                if !Task.isCancelled {
                    lastError = error.localizedDescription
                }
            }
        }
        ensureVisibleMonthTask = task
        await task.value
    }

    func syncAllCalendars() async throws {
        guard isSignedIn else { return }
        guard let eventStore, let calendarStore else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let token = try await oauth.validAccessToken()
            let list = try await api.calendarList(accessToken: token)
            let mapped = list.map { entry in
                let isHoliday = JapaneseHolidayCalendar.isHolidayCalendar(id: entry.id, title: entry.summary)
                let selected = entry.selected ?? true
                return SubscribedCalendar(
                    id: entry.id,
                    title: entry.summary,
                    color: GoogleEventMapper.color(from: entry.backgroundColor),
                    isVisible: selected || isHoliday,
                    canWrite: ["owner", "writer"].contains(entry.accessRole ?? ""),
                    syncToken: SyncTokenStore.token(for: entry.id)
                )
            }
            calendarStore.replace(with: mapped)

            let pullTargets = calendarStore.calendars.filter { $0.isVisible || $0.isJapaneseHolidayCalendar }
            let bootCenter = YearMonth.current()
            for cal in pullTargets {
                if !SyncedMonthStore.isRangeFullySynced(
                    calendarId: cal.id,
                    center: bootCenter,
                    radiusMonths: initialWindowRadiusMonths
                ) {
                    try await pullMonthWindow(
                        calendarId: cal.id,
                        center: bootCenter,
                        radiusMonths: initialWindowRadiusMonths,
                        token: token,
                        eventStore: eventStore,
                        calendarStore: calendarStore
                    )
                }
                try await pullIncrementalIfPossible(
                    calendarId: cal.id,
                    token: token,
                    eventStore: eventStore,
                    calendarStore: calendarStore
                )
            }

            try await flushOutbox(accessToken: token, eventStore: eventStore)
            lastError = nil
            onEventsUpdated?()
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    func enqueueSave(draft: EventDraft) async {
        let payload = draft.toPayload()
        OutboxStore.append(
            SyncOutboxItem(
                id: UUID(),
                calendarId: draft.calendarId,
                operation: .insert(payload),
                createdAt: Date()
            )
        )
        await flushOutboxIfPossible()
    }

    func enqueueUpdate(draft: EventDraft) async {
        var payload = draft.toPayload()
        payload.localEventId = draft.editingEventId
        payload.googleEventId = draft.editingGoogleEventId
        OutboxStore.append(
            SyncOutboxItem(
                id: UUID(),
                calendarId: draft.calendarId,
                operation: .update(payload),
                createdAt: Date()
            )
        )
        await flushOutboxIfPossible()
    }

    func enqueueDelete(calendarId: String, googleEventId: String) async {
        OutboxStore.append(
            SyncOutboxItem(
                id: UUID(),
                calendarId: calendarId,
                operation: .delete(googleEventId: googleEventId),
                createdAt: Date()
            )
        )
        await flushOutboxIfPossible()
    }

    private func flushOutboxIfPossible() async {
        guard let eventStore else { return }
        do {
            try await flushOutbox(accessToken: try await oauth.validAccessToken(), eventStore: eventStore)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func pullEvents(
        calendarId: String,
        token: String,
        eventStore: EventStore,
        calendarStore: SubscribedCalendarStore
    ) async throws {
        guard calendarStore.calendar(id: calendarId) != nil else { return }
        try await pullIncrementalIfPossible(
            calendarId: calendarId,
            token: token,
            eventStore: eventStore,
            calendarStore: calendarStore
        )
    }

    private func pullMonthWindow(
        calendarId: String,
        center: YearMonth,
        radiusMonths: Int,
        token: String,
        eventStore: EventStore,
        calendarStore: SubscribedCalendarStore
    ) async throws {
        guard let cal = calendarStore.calendar(id: calendarId),
              let (timeMin, timeMax) = YearMonth.syncTimeRange(center: center, radiusMonths: radiusMonths) else {
            return
        }

        let (items, nextSync) = try await api.events(
            calendarId: calendarId,
            accessToken: token,
            timeMin: timeMin,
            timeMax: timeMax
        )
        if let nextSync {
            calendarStore.setSyncToken(calendarId: calendarId, token: nextSync)
        }

        let deletedGoogleIds = items.filter { $0.status == "cancelled" }.compactMap(\.id)
        let mapped = items.compactMap { GoogleEventMapper.toCalendarEvent($0, calendarId: calendarId, color: cal.color) }
        eventStore.applyRangeMerge(calendarId: calendarId, remote: mapped, deletedGoogleIds: deletedGoogleIds)
        SyncedMonthStore.markRangeSynced(calendarId: calendarId, center: center, radiusMonths: radiusMonths)
    }

    private func pullIncrementalIfPossible(
        calendarId: String,
        token: String,
        eventStore: EventStore,
        calendarStore: SubscribedCalendarStore
    ) async throws {
        guard let cal = calendarStore.calendar(id: calendarId) else { return }
        guard let syncToken = SyncTokenStore.token(for: calendarId),
              eventStore.hasSyncedEvents(for: calendarId) else { return }

        do {
            try await fetchIncremental(
                calendarId: calendarId,
                token: token,
                syncToken: syncToken,
                eventStore: eventStore,
                calendarStore: calendarStore,
                calendarColor: cal.color
            )
        } catch GoogleAPIError.fullSyncRequired {
            calendarStore.setSyncToken(calendarId: calendarId, token: nil)
            let center = YearMonth.current()
            try await pullMonthWindow(
                calendarId: calendarId,
                center: center,
                radiusMonths: initialWindowRadiusMonths,
                token: token,
                eventStore: eventStore,
                calendarStore: calendarStore
            )
        }
    }

    private func fetchIncremental(
        calendarId: String,
        token: String,
        syncToken: String,
        eventStore: EventStore,
        calendarStore: SubscribedCalendarStore,
        calendarColor: Color
    ) async throws {
        let (items, nextSync) = try await api.events(
            calendarId: calendarId,
            accessToken: token,
            syncToken: syncToken
        )
        if let nextSync {
            calendarStore.setSyncToken(calendarId: calendarId, token: nextSync)
        }
        let deletedGoogleIds = items.filter { $0.status == "cancelled" }.compactMap(\.id)
        let mapped = items.compactMap { GoogleEventMapper.toCalendarEvent($0, calendarId: calendarId, color: calendarColor) }
        eventStore.applyIncrementalPull(calendarId: calendarId, remote: mapped, deletedGoogleIds: deletedGoogleIds)
    }

    private func flushOutbox(accessToken: String, eventStore: EventStore) async throws {
        var outbox = OutboxStore.load()
        guard !outbox.isEmpty else { return }

        var remaining: [SyncOutboxItem] = []

        for item in outbox {
            switch item.operation {
            case .insert(let payload):
                do {
                    let draft = EventDraft.fromPayload(payload)
                    draft.calendarId = item.calendarId
                    let body = GoogleEventMapper.makeInsertBody(from: draft)
                    let created = try await api.insertEvent(
                        calendarId: item.calendarId,
                        body: body,
                        accessToken: accessToken
                    )
                    eventStore.markPendingCreated(
                        calendarId: item.calendarId,
                        title: payload.title,
                        googleEventId: created.id
                    )
                } catch {
                    remaining.append(item)
                    throw error
                }
            case .update(let payload):
                guard let googleId = payload.googleEventId else {
                    remaining.append(item)
                    continue
                }
                do {
                    var draft = EventDraft.fromPayload(payload)
                    draft.calendarId = item.calendarId
                    draft.editingEventId = payload.localEventId
                    draft.editingGoogleEventId = googleId
                    let body = GoogleEventMapper.makeInsertBody(from: draft)
                    _ = try await api.patchEvent(
                        calendarId: item.calendarId,
                        eventId: googleId,
                        body: body,
                        accessToken: accessToken
                    )
                    if let localId = payload.localEventId {
                        eventStore.markSyncedAfterUpdate(eventId: localId)
                    }
                } catch {
                    remaining.append(item)
                    throw error
                }
            case .delete(let googleEventId):
                do {
                    try await api.deleteEvent(
                        calendarId: item.calendarId,
                        eventId: googleEventId,
                        accessToken: accessToken
                    )
                } catch {
                    remaining.append(item)
                    throw error
                }
            }
        }

        OutboxStore.replaceAll(remaining)

        if remaining.count < outbox.count, let calendarStore = self.calendarStore {
            let token = try await oauth.validAccessToken()
            for cal in calendarStore.calendars where cal.isVisible {
                try await pullEvents(calendarId: cal.id, token: token, eventStore: eventStore, calendarStore: calendarStore)
            }
        }
    }
}

private extension EventDraft {
    func toPayload() -> EventDraftPayload {
        let f = ISO8601DateFormatter()
        return EventDraftPayload(
            localEventId: editingEventId,
            googleEventId: editingGoogleEventId,
            calendarId: calendarId,
            title: title,
            isAllDay: isAllDay,
            startISO8601: f.string(from: start),
            endISO8601: f.string(from: end),
            selectedDays: Array(selectedDays).sorted(),
            recurrence: recurrence,
            reminderMinutes: reminderMinutes,
            location: location.isEmpty ? nil : location,
            url: urlString.isEmpty ? nil : urlString,
            notes: notes.isEmpty ? nil : notes
        )
    }

    static func fromPayload(_ payload: EventDraftPayload) -> EventDraft {
        let f = ISO8601DateFormatter()
        let start = f.date(from: payload.startISO8601) ?? Date()
        let startDay = LocalDay(start)
        let draft = EventDraft(calendarId: payload.calendarId, startDay: startDay)
        draft.title = payload.title
        draft.isAllDay = payload.isAllDay
        draft.start = start
        draft.end = f.date(from: payload.endISO8601) ?? start
        draft.selectedDays = Set(payload.selectedDays)
        draft.recurrence = payload.recurrence
        draft.reminderMinutes = payload.reminderMinutes
        draft.location = payload.location ?? ""
        draft.urlString = payload.url ?? ""
        draft.notes = payload.notes ?? ""
        draft.editingEventId = payload.localEventId
        draft.editingGoogleEventId = payload.googleEventId
        return draft
    }
}
