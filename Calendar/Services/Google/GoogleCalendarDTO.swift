import Foundation

struct GCalendarListResponse: Decodable {
    var items: [GCalendarListEntry]?
}

struct GCalendarListEntry: Decodable {
    var id: String
    var summary: String
    var backgroundColor: String?
    var accessRole: String?
    var selected: Bool?
    var primary: Bool?
}

struct GEventsListResponse: Decodable {
    var items: [GCalendarEvent]?
    var nextPageToken: String?
    var nextSyncToken: String?
}

struct GCalendarEvent: Decodable {
    var id: String
    var status: String?
    var summary: String?
    var description: String?
    var location: String?
    var htmlLink: String?
    var source: GEventSource?
    var etag: String?
    var start: GEventDateTime?
    var end: GEventDateTime?
    var recurrence: [String]?
    var reminders: GEventReminders?
}


struct GEventReminders: Codable {
    var useDefault: Bool?
    var overrides: [GReminderOverride]?
}

struct GEventDateTime: Decodable {
    var date: String?
    var dateTime: String?
    var timeZone: String?
}

struct GCalendarEventInsertBody: Encodable {
    var summary: String
    var description: String?
    var location: String?
    var start: GEventDateTimeEncodable
    var end: GEventDateTimeEncodable
    var recurrence: [String]?
    var reminders: GReminders?
    var source: GEventSource?
}

struct GEventDateTimeEncodable: Encodable {
    var date: String?
    var dateTime: String?
    var timeZone: String?
}

struct GReminders: Encodable {
    var useDefault: Bool
    var overrides: [GReminderOverride]?
}

struct GReminderOverride: Codable {
    var method: String
    var minutes: Int
}

struct GEventSource: Codable {
    var url: String?
    var title: String?
}
