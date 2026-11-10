import Foundation
import SwiftData
import SwiftUI

struct SubscribedCalendar: Identifiable, Hashable {
    var id: String
    var title: String
    var color: Color
    var isVisible: Bool
    var canWrite: Bool
    var syncToken: String?

    var isJapaneseHolidayCalendar: Bool {
        JapaneseHolidayCalendar.isHolidayCalendar(id: id, title: title)
    }
}

/// Google「日本の祝日」などの祝日専用カレンダー判定。
enum JapaneseHolidayCalendar {
    static let googleCalendarId = "ja.japanese#holiday@group.v.calendar.google.com"

    static func isHolidayCalendar(id: String, title: String) -> Bool {
        if id == googleCalendarId { return true }
        if id.contains("holiday") { return true }
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedTitle.contains("祝日") { return true }
        if normalizedTitle.contains("国民の祝日") { return true }
        if normalizedTitle.localizedCaseInsensitiveContains("Holidays in Japan") { return true }
        if normalizedTitle.localizedCaseInsensitiveContains("Japanese holidays") { return true }
        return false
    }
}

@Observable
final class SubscribedCalendarStore {
    var calendars: [SubscribedCalendar]

    private let context: ModelContext?

    init(calendars: [SubscribedCalendar] = [], context: ModelContext? = nil) {
        self.context = context
        if let context, calendars.isEmpty {
            self.calendars = Self.fetchCalendars(from: context)
        } else {
            self.calendars = calendars
        }
    }

    var defaultCalendarId: String {
        calendars.first(where: \.canWrite)?.id ?? calendars.first?.id ?? "primary"
    }

    func calendar(id: String) -> SubscribedCalendar? {
        calendars.first { $0.id == id }
    }

    func replace(with calendars: [SubscribedCalendar]) {
        self.calendars = calendars
        persistAll()
    }

    func setVisibility(calendarId: String, visible: Bool) {
        guard let index = calendars.firstIndex(where: { $0.id == calendarId }) else { return }
        calendars[index].isVisible = visible
        upsertStored(calendars[index])
        try? context?.save()
    }

    func setSyncToken(calendarId: String, token: String?) {
        guard let index = calendars.firstIndex(where: { $0.id == calendarId }) else { return }
        calendars[index].syncToken = token
        upsertStored(calendars[index])
        try? context?.save()
        SyncTokenStore.set(token, for: calendarId)
    }

    private func persistAll() {
        guard let context else { return }
        if let existing = try? context.fetch(FetchDescriptor<StoredSubscribedCalendar>()) {
            for row in existing {
                context.delete(row)
            }
        }
        for calendar in calendars {
            context.insert(StoredSubscribedCalendar(from: calendar))
        }
        try? context.save()
    }

    private func upsertStored(_ calendar: SubscribedCalendar) {
        guard let context else { return }
        let calendarId = calendar.id
        var descriptor = FetchDescriptor<StoredSubscribedCalendar>(
            predicate: #Predicate { $0.id == calendarId }
        )
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            existing.apply(from: calendar)
        } else {
            context.insert(StoredSubscribedCalendar(from: calendar))
        }
    }

    private static func fetchCalendars(from context: ModelContext) -> [SubscribedCalendar] {
        let descriptor = FetchDescriptor<StoredSubscribedCalendar>(
            sortBy: [SortDescriptor(\.title, order: .forward)]
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.map { $0.toSubscribedCalendar() }
    }

    static let preview: SubscribedCalendarStore = {
        SubscribedCalendarStore(calendars: [
            SubscribedCalendar(id: "schedule", title: "スケジュール", color: .blue, isVisible: true, canWrite: true, syncToken: nil),
            SubscribedCalendar(id: "work", title: "仕事", color: .orange, isVisible: true, canWrite: true, syncToken: nil),
        ])
    }()
}
