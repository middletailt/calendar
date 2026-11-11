import Foundation
import SwiftData
import SwiftUI
import Observation

@Observable
final class EventStore {
    private(set) var events: [CalendarEvent]

    private let context: ModelContext?
    /// `refreshMemoryCache` の中心。同期マージ後に窓へ戻すときに使う。
    private var memoryCacheCenter = YearMonth.current()

    init(events: [CalendarEvent] = [], context: ModelContext? = nil) {
        self.context = context
        if let context, events.isEmpty {
            let center = YearMonth.current()
            if let range = YearMonth.syncTimeRange(
                center: center,
                radiusMonths: MonthGridLimits.memoryWindowRadiusMonths
            ) {
                self.events = Self.fetchEvents(from: context, from: range.timeMin, to: range.timeMax)
            } else {
                self.events = []
            }
            dedupeSyncedEvents()
        } else {
            self.events = events
        }
    }

    func clearAll() {
        events = []
        guard let context else { return }
        if let stored = try? context.fetch(FetchDescriptor<StoredCalendarEvent>()) {
            for row in stored {
                context.delete(row)
            }
        }
        try? context.save()
    }

    /// 初回・フル同期: そのカレンダーの同期済み予定をリモート一覧で置き換える。
    func applyFullPull(calendarId: String, remote: [CalendarEvent]) {
        let pending = events.filter { $0.calendarId == calendarId && $0.syncState != .synced }
        events.removeAll { $0.calendarId == calendarId && $0.syncState == .synced }
        events.append(contentsOf: remote)
        events.append(contentsOf: pending)

        guard let context else { return }
        deleteStoredSynced(calendarId: calendarId, in: context)
        for event in remote {
            upsertStored(event, in: context)
        }
        try? context.save()
        trimMemoryToWindowAfterSync()
    }

    /// 期間リスト同期: 取得範囲のイベントをマージ（範囲外の既存データは残す）。
    func applyRangeMerge(calendarId: String, remote: [CalendarEvent], deletedGoogleIds: [String]) {
        for googleId in deletedGoogleIds {
            events.removeAll { $0.calendarId == calendarId && $0.googleEventId == googleId }
            deleteStored(googleEventId: googleId, calendarId: calendarId)
        }
        for event in remote where event.syncState == .synced {
            if let googleEventId = event.googleEventId {
                removeDuplicates(calendarId: calendarId, googleEventId: googleEventId, keepingId: event.id)
            }
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index] = event
            } else {
                events.append(event)
            }
            upsertStored(event)
        }
        try? context?.save()
        trimMemoryToWindowAfterSync()
    }

    /// 増分同期: 変更分のみマージし、キャンセル分は削除する。
    func applyIncrementalPull(calendarId: String, remote: [CalendarEvent], deletedGoogleIds: [String]) {
        for googleId in deletedGoogleIds {
            events.removeAll { $0.calendarId == calendarId && $0.googleEventId == googleId }
            deleteStored(googleEventId: googleId, calendarId: calendarId)
        }
        for event in remote {
            if let googleEventId = event.googleEventId {
                removeDuplicates(calendarId: calendarId, googleEventId: googleEventId, keepingId: event.id)
            }
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index] = event
            } else {
                events.append(event)
            }
            upsertStored(event)
        }
        try? context?.save()
        trimMemoryToWindowAfterSync()
    }

    func hasSyncedEvents(for calendarId: String) -> Bool {
        events.contains { $0.calendarId == calendarId && $0.syncState == .synced }
    }

    func markPendingCreated(calendarId: String, title: String, googleEventId: String) {
        guard let index = events.firstIndex(where: {
            $0.calendarId == calendarId && $0.syncState == .pendingCreate && $0.title == title && $0.googleEventId == nil
        }) else { return }
        let oldId = events[index].id
        let newId = "\(calendarId):\(googleEventId)"
        events[index].googleEventId = googleEventId
        events[index].syncState = .synced
        events[index].id = newId
        removeDuplicates(calendarId: calendarId, googleEventId: googleEventId, keepingId: newId)
        if oldId != newId {
            deleteStored(eventId: oldId)
        }
        upsertStored(events[index])
        try? context?.save()
    }

    func event(id: String) -> CalendarEvent? {
        events.first { $0.id == id }
    }

    func search(query: String, visibleCalendarIds: Set<String>, limit: Int = 80) -> [CalendarEvent] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let source: [CalendarEvent]
        if let context {
            source = Self.fetchEvents(from: context)
        } else {
            source = events
        }
        return source
            .filter { visibleCalendarIds.contains($0.calendarId) }
            .filter { event in
                event.title.localizedCaseInsensitiveContains(trimmed)
                    || event.location?.localizedCaseInsensitiveContains(trimmed) == true
                    || event.notes?.localizedCaseInsensitiveContains(trimmed) == true
                    || event.url?.absoluteString.localizedCaseInsensitiveContains(trimmed) == true
            }
            .sorted { $0.start < $1.start }
            .prefix(limit)
            .map { $0 }
    }

    func update(from draft: EventDraft, calendar: SubscribedCalendar, sync: GoogleCalendarSyncing) {
        guard let eventId = draft.editingEventId,
              let index = events.firstIndex(where: { $0.id == eventId }) else { return }
        let prior = events[index]
        let updated = event(from: draft, calendar: calendar, base: prior)
        events[index] = updated
        upsertStored(updated)
        try? context?.save()
        Task {
            if prior.googleEventId != nil {
                await sync.enqueueUpdate(draft: draft)
            }
        }
    }

    func markSyncedAfterUpdate(eventId: String) {
        guard let index = events.firstIndex(where: { $0.id == eventId }) else { return }
        events[index].syncState = .synced
        upsertStored(events[index])
        try? context?.save()
    }

    func delete(event: CalendarEvent, sync: GoogleCalendarSyncing) {
        events.removeAll { $0.id == event.id }
        deleteStored(eventId: event.id)
        try? context?.save()
        if let googleEventId = event.googleEventId {
            Task {
                await sync.enqueueDelete(calendarId: event.calendarId, googleEventId: googleEventId)
            }
        }
    }

    func events(on day: LocalDay, visibleCalendarIds: Set<String>) -> [CalendarEvent] {
        events
            .filter { visibleCalendarIds.contains($0.calendarId) }
            .filter { $0.occurs(on: day) }
            .sorted(by: { $0.start < $1.start })
    }

    /// メモリ上の `events` を表示中心付近だけに絞る（ディスク上は全件のまま）。
    func refreshMemoryCache(center: YearMonth, radiusMonths: Int = MonthGridLimits.memoryWindowRadiusMonths) {
        memoryCacheCenter = center
        guard let context else { return }
        guard let range = YearMonth.syncTimeRange(center: center, radiusMonths: radiusMonths) else { return }

        let pending = events.filter { $0.syncState != .synced }
        var windowed = Self.fetchEvents(from: context, from: range.timeMin, to: range.timeMax)
        let inWindow = Set(windowed.map(\.id))
        for event in pending where !inWindow.contains(event.id) {
            windowed.append(event)
        }
        events = windowed
    }

    /// Google 増分同期などで `events` に一時的に載った範囲外データを捨てる。
    private func trimMemoryToWindowAfterSync() {
        guard context != nil else { return }
        refreshMemoryCache(center: memoryCacheCenter)
    }

    /// 通知再スケジュール用（直近のみ DB から取得）
    func eventsForNotificationScheduling(calendar: Calendar = .current) -> [CalendarEvent] {
        guard let context else { return events }
        let now = Date()
        guard let horizon = calendar.date(byAdding: .month, value: 4, to: now) else { return events }
        let lookback = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        return Self.fetchEvents(from: context, from: lookback, to: horizon)
    }

    /// 月グリッド 1 枚分の行データをまとめて構築（ドラッグ中の再計算を抑える）。
    func eventLinesByDay(
        for month: YearMonth,
        visibleCalendarIds: Set<String>,
        holidayCalendarIds: Set<String>
    ) -> [LocalDay: [MonthCellEventLine]] {
        let days = MonthGridBuilder.days(for: month)
        var map: [LocalDay: [MonthCellEventLine]] = [:]
        map.reserveCapacity(days.count)
        for cell in days {
            map[cell.day] = []
        }

        let calendarIds = visibleCalendarIds.union(holidayCalendarIds)
        guard let monthRange = YearMonth.syncTimeRange(center: month, radiusMonths: 1) else { return map }

        let candidates = events
            .filter { calendarIds.contains($0.calendarId) }
            .filter { eventIntersectsRange($0, timeMin: monthRange.timeMin, timeMax: monthRange.timeMax) }
            .sorted { lhs, rhs in
                let lhsHoliday = holidayCalendarIds.contains(lhs.calendarId)
                let rhsHoliday = holidayCalendarIds.contains(rhs.calendarId)
                if lhsHoliday != rhsHoliday { return lhsHoliday }
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                return lhs.start < rhs.start
            }
        for event in candidates {
            for cell in days where event.occurs(on: cell.day) {
                map[cell.day, default: []].append(makeMonthCellLine(for: event, holidayCalendarIds: holidayCalendarIds))
            }
        }

        for day in map.keys {
            guard var lines = map[day] else { continue }
            lines.sort { lhs, rhs in
                if lhs.isHoliday != rhs.isHoliday { return lhs.isHoliday }
                if lhs.style != rhs.style { return lhs.style == .band }
                return lhs.title < rhs.title
            }
            if lines.count > MonthGridLimits.maxEventLinesPerDay {
                lines = Array(lines.prefix(MonthGridLimits.maxEventLinesPerDay))
            }
            map[day] = lines
        }
        return map
    }

    private func eventIntersectsRange(_ event: CalendarEvent, timeMin: Date, timeMax: Date) -> Bool {
        if event.isAllDay {
            return event.end > timeMin && event.start < timeMax
        }
        return event.end > timeMin && event.start < timeMax
    }

    private func makeMonthCellLine(for event: CalendarEvent, holidayCalendarIds: Set<String>) -> MonthCellEventLine {
        let isHoliday = holidayCalendarIds.contains(event.calendarId)
        let useBand = isHoliday || event.isAllDay
        return MonthCellEventLine(
            id: event.id,
            title: event.title,
            isHoliday: isHoliday,
            style: useBand ? .band : .compact,
            accentColor: event.color
        )
    }

    /// 月グリッド用: 祝日→終日は帯、時間指定はテキストのみ。
    func monthCellEventLines(
        on day: LocalDay,
        visibleCalendarIds: Set<String>,
        holidayCalendarIds: Set<String>
    ) -> [MonthCellEventLine] {
        let ids = visibleCalendarIds.union(holidayCalendarIds)
        let dayEvents = events
            .filter { ids.contains($0.calendarId) }
            .filter { $0.occurs(on: day) }
            .sorted { lhs, rhs in
                let lhsHoliday = holidayCalendarIds.contains(lhs.calendarId)
                let rhsHoliday = holidayCalendarIds.contains(rhs.calendarId)
                if lhsHoliday != rhsHoliday { return lhsHoliday }
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                return lhs.start < rhs.start
            }

        return dayEvents.map { event in
            let isHoliday = holidayCalendarIds.contains(event.calendarId)
            let useBand = isHoliday || event.isAllDay
            return MonthCellEventLine(
                id: event.id,
                title: event.title,
                isHoliday: isHoliday,
                style: useBand ? .band : .compact,
                accentColor: event.color
            )
        }
    }

    func add(from draft: EventDraft, calendar: SubscribedCalendar, sync: GoogleCalendarSyncing) {
        switch draft.saveShape {
        case .single:
            appendLocalEvent(from: draft, calendar: calendar, day: LocalDay(draft.start))
        case .rdates(let days):
            for day in days.sorted() {
                appendLocalEvent(from: draft, calendar: calendar, day: day)
            }
        case .recurrence(let rule):
            var master = makeEvent(from: draft, calendar: calendar, start: draft.start, end: draft.end)
            master.title += " (\(rule.frequency.title))"
            events.append(master)
            upsertStored(master)
        }
        try? context?.save()
        Task {
            await sync.enqueueSave(draft: draft)
        }
    }

    private func appendLocalEvent(from draft: EventDraft, calendar: SubscribedCalendar, day: LocalDay) {
        let cal = Calendar.current
        guard let dayDate = day.date(calendar: cal) else { return }
        let start: Date
        let end: Date
        if draft.isAllDay {
            start = dayDate
            end = cal.date(byAdding: .day, value: 1, to: dayDate) ?? dayDate
        } else {
            let sh = cal.component(.hour, from: draft.start)
            let sm = cal.component(.minute, from: draft.start)
            let eh = cal.component(.hour, from: draft.end)
            let em = cal.component(.minute, from: draft.end)
            start = cal.date(bySettingHour: sh, minute: sm, second: 0, of: dayDate) ?? dayDate
            end = cal.date(bySettingHour: eh, minute: em, second: 0, of: dayDate) ?? dayDate
        }
        let event = makeEvent(from: draft, calendar: calendar, start: start, end: end)
        events.append(event)
        upsertStored(event)
    }

    private func makeEvent(
        from draft: EventDraft,
        calendar: SubscribedCalendar,
        start: Date,
        end: Date
    ) -> CalendarEvent {
        CalendarEvent(
            id: UUID().uuidString,
            googleEventId: nil,
            calendarId: calendar.id,
            title: draft.title.isEmpty ? "(タイトルなし)" : draft.title,
            isAllDay: draft.isAllDay,
            start: start,
            end: end,
            location: draft.location.isEmpty ? nil : draft.location,
            url: URL(string: draft.urlString),
            notes: draft.notes.isEmpty ? nil : draft.notes,
            syncState: .pendingCreate,
            reminderMinutes: draft.reminderMinutes,
            color: calendar.color
        )
    }

    private func event(from draft: EventDraft, calendar: SubscribedCalendar, base: CalendarEvent) -> CalendarEvent {
        let cal = Calendar.current
        var start = draft.start
        var end = draft.end
        if draft.isAllDay {
            let day = LocalDay(draft.start)
            if let dayDate = day.date(calendar: cal) {
                start = dayDate
                end = cal.date(byAdding: .day, value: 1, to: dayDate) ?? dayDate
            }
        }
        let syncState: SyncState = base.googleEventId == nil ? base.syncState : .pendingUpdate
        return CalendarEvent(
            id: base.id,
            googleEventId: base.googleEventId,
            calendarId: calendar.id,
            title: draft.title.isEmpty ? "(タイトルなし)" : draft.title,
            isAllDay: draft.isAllDay,
            start: start,
            end: end,
            location: draft.location.isEmpty ? nil : draft.location,
            url: URL(string: draft.urlString),
            notes: draft.notes.isEmpty ? nil : draft.notes,
            syncState: syncState,
            reminderMinutes: draft.reminderMinutes,
            color: calendar.color
        )
    }

    private func deleteStored(eventId: String) {
        guard let context else { return }
        var descriptor = FetchDescriptor<StoredCalendarEvent>(
            predicate: #Predicate { $0.id == eventId }
        )
        descriptor.fetchLimit = 1
        if let row = try? context.fetch(descriptor).first {
            context.delete(row)
        }
    }

    private func removeDuplicates(calendarId: String, googleEventId: String, keepingId: String) {
        let duplicates = events.filter {
            $0.calendarId == calendarId && $0.googleEventId == googleEventId && $0.id != keepingId
        }
        for duplicate in duplicates {
            events.removeAll { $0.id == duplicate.id }
            deleteStored(eventId: duplicate.id)
        }
    }

    /// 起動時など: 同一 googleEventId の重複行（旧 UUID など）を掃除する。
    private func dedupeSyncedEvents() {
        var keepers: [String: String] = [:]
        var removeIds: [String] = []
        for event in events {
            guard let googleEventId = event.googleEventId else { continue }
            let key = "\(event.calendarId):\(googleEventId)"
            if let existingId = keepers[key] {
                let preferCanonical = event.id == key || existingId != key
                if preferCanonical && event.id == key {
                    removeIds.append(existingId)
                    keepers[key] = event.id
                } else {
                    removeIds.append(event.id)
                }
            } else {
                keepers[key] = event.id
            }
        }
        for id in Set(removeIds) {
            events.removeAll { $0.id == id }
            deleteStored(eventId: id)
        }
        if !removeIds.isEmpty {
            try? context?.save()
        }
    }

    private static func fetchEvents(
        from context: ModelContext,
        from rangeStart: Date? = nil,
        to rangeEnd: Date? = nil
    ) -> [CalendarEvent] {
        let rows: [StoredCalendarEvent]
        if let rangeStart, let rangeEnd {
            let start = rangeStart
            let end = rangeEnd
            let descriptor = FetchDescriptor<StoredCalendarEvent>(
                predicate: #Predicate { row in
                    row.end > start && row.start < end
                }
            )
            rows = (try? context.fetch(descriptor)) ?? []
        } else {
            var descriptor = FetchDescriptor<StoredCalendarEvent>()
            descriptor.fetchLimit = 8_000
            rows = (try? context.fetch(descriptor)) ?? []
        }
        return rows.map { $0.toCalendarEvent() }
    }

    private func upsertStored(_ event: CalendarEvent, in context: ModelContext? = nil) {
        let ctx = context ?? self.context
        guard let ctx else { return }
        let eventId = event.id
        var descriptor = FetchDescriptor<StoredCalendarEvent>(
            predicate: #Predicate { $0.id == eventId }
        )
        descriptor.fetchLimit = 1
        if let existing = try? ctx.fetch(descriptor).first {
            existing.apply(from: event)
        } else {
            ctx.insert(StoredCalendarEvent(from: event))
        }
    }

    private func deleteStoredSynced(calendarId: String, in context: ModelContext) {
        let syncedRaw = SyncState.synced.rawValue
        let descriptor = FetchDescriptor<StoredCalendarEvent>(
            predicate: #Predicate {
                $0.calendarId == calendarId && $0.syncStateRaw == syncedRaw
            }
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        for row in rows {
            context.delete(row)
        }
    }

    private func deleteStored(googleEventId: String, calendarId: String) {
        guard let context else { return }
        var descriptor = FetchDescriptor<StoredCalendarEvent>(
            predicate: #Predicate {
                $0.calendarId == calendarId && $0.googleEventId == googleEventId
            }
        )
        descriptor.fetchLimit = 1
        if let row = try? context.fetch(descriptor).first {
            context.delete(row)
        }
    }

    static let previewEvents: [CalendarEvent] = {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2027
        comps.month = 3
        comps.day = 8
        let start = cal.date(from: comps)!
        let eventStart = cal.date(bySettingHour: 18, minute: 30, second: 0, of: start)!
        let eventEnd = cal.date(bySettingHour: 21, minute: 0, second: 0, of: start)!
        return [
            CalendarEvent(
                id: "preview-1",
                googleEventId: "g-1",
                calendarId: "schedule",
                title: "勉強会",
                isAllDay: false,
                start: eventStart,
                end: eventEnd,
                location: nil,
                url: nil,
                notes: nil,
                syncState: .synced,
                reminderMinutes: [30],
                color: .blue
            ),
        ]
    }()
}
