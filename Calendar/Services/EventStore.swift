import Foundation
import SwiftUI
import Observation

@Observable
final class EventStore {
    private(set) var events: [CalendarEvent]

    init(events: [CalendarEvent] = EventStore.previewEvents) {
        self.events = events
    }

    func events(on day: LocalDay, visibleCalendarIds: Set<String>) -> [CalendarEvent] {
        events
            .filter { visibleCalendarIds.contains($0.calendarId) }
            .filter { $0.occurs(on: day) }
            .sorted(by: { $0.start < $1.start })
    }

    func titlesForMonthCell(day: LocalDay, visibleCalendarIds: Set<String>) -> [String] {
        events(on: day, visibleCalendarIds: visibleCalendarIds).map(\.title)
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
        }
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
        events.append(makeEvent(from: draft, calendar: calendar, start: start, end: end))
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
            color: calendar.color
        )
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
                color: .blue
            ),
        ]
    }()
}
