import Foundation
import SwiftUI

enum GoogleEventMapper {
    private static let rfc3339: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static var allDayFormatter: DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = Calendar.current.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    static func toCalendarEvent(_ item: GCalendarEvent, calendarId: String, color: Color) -> CalendarEvent? {
        guard item.status != "cancelled" else { return nil }
        let isAllDay = item.start?.date != nil
        guard var start = parseStart(item.start) else { return nil }
        guard var end = parseEnd(item.end, isAllDay: isAllDay, start: start) else { return nil }
        if isAllDay {
            end = normalizedAllDayEnd(start: start, end: end)
        }
        let notes = item.description
        let userURL = item.source?.url.flatMap(URL.init(string:))
        return CalendarEvent(
            id: "\(calendarId):\(item.id)",
            googleEventId: item.id,
            calendarId: calendarId,
            title: item.summary ?? "(タイトルなし)",
            isAllDay: isAllDay,
            start: start,
            end: end,
            location: item.location,
            url: userURL,
            notes: notes,
            syncState: .synced,
            reminderMinutes: reminderMinutes(from: item.reminders),
            color: color
        )
    }

    static func reminderMinutes(from reminders: GEventReminders?) -> [Int] {
        guard let reminders else { return [] }
        if reminders.useDefault == true {
            return [10]
        }
        return (reminders.overrides ?? [])
            .filter { $0.method == "popup" || $0.method == "email" }
            .map(\.minutes)
    }

    static func makeInsertBody(from draft: EventDraft, timeZone: TimeZone = .current) -> GCalendarEventInsertBody {
        let tz = timeZone.identifier
        let summary = draft.title.isEmpty ? "(タイトルなし)" : draft.title
        var recurrence: [String]?

        let utcUntil = ISO8601DateFormatter()
        utcUntil.formatOptions = [.withInternetDateTime]

        switch draft.saveShape {
        case .single:
            break
        case .recurrence(let rule):
            if let line = rule.rruleLine(until: utcUntil) {
                recurrence = ["RRULE:\(line)"]
            }
        case .rdates(let days):
            let sorted = days.sorted()
            let rdates = sorted.map { rdateLine(day: $0, isAllDay: draft.isAllDay, timeZone: tz, draft: draft) }
            recurrence = rdates
        }

        let (startEnc, endEnc) = encodeRange(from: draft, timeZone: tz)

        var desc = draft.notes
        if !draft.urlString.isEmpty {
            let extra = draft.urlString
            desc = [desc, extra].filter { !$0.isEmpty }.joined(separator: "\n")
        }

        let reminders: GReminders? = draft.reminderMinutes.isEmpty
            ? nil
            : GReminders(
                useDefault: false,
                overrides: draft.reminderMinutes.map { GReminderOverride(method: "popup", minutes: $0) }
            )

        let source = draft.urlString.isEmpty ? nil : GEventSource(url: draft.urlString, title: "URL")

        return GCalendarEventInsertBody(
            summary: summary,
            description: desc.isEmpty ? nil : desc,
            location: draft.location.isEmpty ? nil : draft.location,
            start: startEnc,
            end: endEnc,
            recurrence: recurrence,
            reminders: reminders,
            source: source
        )
    }

    private static func rdateLine(day: LocalDay, isAllDay: Bool, timeZone: String, draft: EventDraft) -> String {
        if isAllDay {
            guard let date = day.date() else { return "" }
            let s = allDayFormatter.string(from: date)
            return "RDATE;VALUE=DATE:\(s.replacingOccurrences(of: "-", with: ""))"
        }
        let cal = Calendar.current
        guard let dayDate = day.date(calendar: cal) else { return "" }
        let sh = cal.component(.hour, from: draft.start)
        let sm = cal.component(.minute, from: draft.start)
        let start = cal.date(bySettingHour: sh, minute: sm, second: 0, of: dayDate) ?? dayDate
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd'T'HHmmss"
        f.timeZone = TimeZone(identifier: timeZone)
        return "RDATE;TZID=\(timeZone):\(f.string(from: start))"
    }

    private static func encodeRange(from draft: EventDraft, timeZone: String) -> (GEventDateTimeEncodable, GEventDateTimeEncodable) {
        if draft.isAllDay {
            let startDay = LocalDay(draft.start)
            guard let startDate = startDay.date() else {
                return (GEventDateTimeEncodable(date: nil, dateTime: nil, timeZone: nil),
                        GEventDateTimeEncodable(date: nil, dateTime: nil, timeZone: nil))
            }
            let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
            return (
                GEventDateTimeEncodable(date: allDayFormatter.string(from: startDate), dateTime: nil, timeZone: nil),
                GEventDateTimeEncodable(date: allDayFormatter.string(from: endDate), dateTime: nil, timeZone: nil)
            )
        }
        return (
            GEventDateTimeEncodable(date: nil, dateTime: rfc3339.string(from: draft.start), timeZone: timeZone),
            GEventDateTimeEncodable(date: nil, dateTime: rfc3339.string(from: draft.end), timeZone: timeZone)
        )
    }

    private static func parseStart(_ dt: GEventDateTime?) -> Date? {
        guard let dt else { return nil }
        if let date = dt.date {
            return allDayFormatter.date(from: date)
        }
        if let dateTime = dt.dateTime {
            return rfc3339.date(from: dateTime) ?? ISO8601DateFormatter().date(from: dateTime)
        }
        return nil
    }

    private static func parseEnd(_ dt: GEventDateTime?, isAllDay: Bool, start: Date) -> Date? {
        if isAllDay {
            if let date = dt?.date, let parsed = allDayFormatter.date(from: date) {
                return parsed
            }
            return Calendar.current.date(byAdding: .day, value: 1, to: start)
        }
        guard let dt else { return nil }
        if let dateTime = dt.dateTime {
            return rfc3339.date(from: dateTime) ?? ISO8601DateFormatter().date(from: dateTime)
        }
        return nil
    }

    private static func normalizedAllDayEnd(start: Date, end: Date) -> Date {
        let cal = Calendar.current
        let startDay = LocalDay(start)
        let endDay = LocalDay(end)
        if endDay <= startDay, let next = cal.date(byAdding: .day, value: 1, to: start) {
            return next
        }
        return end
    }

    static func color(from hex: String?) -> Color {
        guard let hex, hex.hasPrefix("#"), hex.count == 7 else { return .blue }
        let r = Int(hex.dropFirst(1).prefix(2), radix: 16) ?? 0
        let g = Int(hex.dropFirst(3).prefix(2), radix: 16) ?? 0
        let b = Int(hex.dropFirst(5).prefix(2), radix: 16) ?? 0
        return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
