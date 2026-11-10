import Foundation
import SwiftData
import SwiftUI

@Model
final class StoredCalendarEvent {
    @Attribute(.unique) var id: String
    var googleEventId: String?
    var calendarId: String
    var title: String
    var isAllDay: Bool
    var start: Date
    var end: Date
    var location: String?
    var notes: String?
    var urlString: String?
    var syncStateRaw: String
    var reminderMinutesJSON: Data
    var colorHex: String

    init(
        id: String,
        googleEventId: String?,
        calendarId: String,
        title: String,
        isAllDay: Bool,
        start: Date,
        end: Date,
        location: String?,
        notes: String?,
        urlString: String?,
        syncStateRaw: String,
        reminderMinutesJSON: Data,
        colorHex: String
    ) {
        self.id = id
        self.googleEventId = googleEventId
        self.calendarId = calendarId
        self.title = title
        self.isAllDay = isAllDay
        self.start = start
        self.end = end
        self.location = location
        self.notes = notes
        self.urlString = urlString
        self.syncStateRaw = syncStateRaw
        self.reminderMinutesJSON = reminderMinutesJSON
        self.colorHex = colorHex
    }

    convenience init(from event: CalendarEvent) {
        let minutesData = (try? JSONEncoder().encode(event.reminderMinutes)) ?? Data()
        self.init(
            id: event.id,
            googleEventId: event.googleEventId,
            calendarId: event.calendarId,
            title: event.title,
            isAllDay: event.isAllDay,
            start: event.start,
            end: event.end,
            location: event.location,
            notes: event.notes,
            urlString: event.url?.absoluteString,
            syncStateRaw: event.syncState.rawValue,
            reminderMinutesJSON: minutesData,
            colorHex: ColorStorage.hex(from: event.color)
        )
    }

    func apply(from event: CalendarEvent) {
        id = event.id
        googleEventId = event.googleEventId
        calendarId = event.calendarId
        title = event.title
        isAllDay = event.isAllDay
        start = event.start
        end = event.end
        location = event.location
        notes = event.notes
        urlString = event.url?.absoluteString
        syncStateRaw = event.syncState.rawValue
        reminderMinutesJSON = (try? JSONEncoder().encode(event.reminderMinutes)) ?? reminderMinutesJSON
        colorHex = ColorStorage.hex(from: event.color)
    }

    func toCalendarEvent() -> CalendarEvent {
        let minutes = (try? JSONDecoder().decode([Int].self, from: reminderMinutesJSON)) ?? []
        let syncState = SyncState(rawValue: syncStateRaw) ?? .synced
        return CalendarEvent(
            id: id,
            googleEventId: googleEventId,
            calendarId: calendarId,
            title: title,
            isAllDay: isAllDay,
            start: start,
            end: end,
            location: location,
            url: urlString.flatMap(URL.init(string:)),
            notes: notes,
            syncState: syncState,
            reminderMinutes: minutes,
            color: ColorStorage.color(from: colorHex)
        )
    }
}

@Model
final class StoredSubscribedCalendar {
    @Attribute(.unique) var id: String
    var title: String
    var colorHex: String
    var isVisible: Bool
    var canWrite: Bool
    var syncToken: String?

    init(
        id: String,
        title: String,
        colorHex: String,
        isVisible: Bool,
        canWrite: Bool,
        syncToken: String?
    ) {
        self.id = id
        self.title = title
        self.colorHex = colorHex
        self.isVisible = isVisible
        self.canWrite = canWrite
        self.syncToken = syncToken
    }

    convenience init(from calendar: SubscribedCalendar) {
        self.init(
            id: calendar.id,
            title: calendar.title,
            colorHex: ColorStorage.hex(from: calendar.color),
            isVisible: calendar.isVisible,
            canWrite: calendar.canWrite,
            syncToken: calendar.syncToken
        )
    }

    func apply(from calendar: SubscribedCalendar) {
        title = calendar.title
        colorHex = ColorStorage.hex(from: calendar.color)
        isVisible = calendar.isVisible
        canWrite = calendar.canWrite
        syncToken = calendar.syncToken
    }

    func toSubscribedCalendar() -> SubscribedCalendar {
        SubscribedCalendar(
            id: id,
            title: title,
            color: ColorStorage.color(from: colorHex),
            isVisible: isVisible,
            canWrite: canWrite,
            syncToken: syncToken
        )
    }
}

@Model
final class StoredOutboxItem {
    @Attribute(.unique) var itemId: UUID
    var calendarId: String
    var operationJSON: Data
    var createdAt: Date

    init(itemId: UUID, calendarId: String, operationJSON: Data, createdAt: Date) {
        self.itemId = itemId
        self.calendarId = calendarId
        self.operationJSON = operationJSON
        self.createdAt = createdAt
    }

    convenience init(from item: SyncOutboxItem) throws {
        let opData = try JSONEncoder().encode(item.operation)
        self.init(
            itemId: item.id,
            calendarId: item.calendarId,
            operationJSON: opData,
            createdAt: item.createdAt
        )
    }

    func toSyncOutboxItem() -> SyncOutboxItem? {
        guard let operation = try? JSONDecoder().decode(OutboxOperation.self, from: operationJSON) else {
            return nil
        }
        return SyncOutboxItem(id: itemId, calendarId: calendarId, operation: operation, createdAt: createdAt)
    }
}
