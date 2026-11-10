import Foundation
import Observation

@Observable
final class EventDraft {
    /// 編集時のローカル ID（`CalendarEvent.id`）。
    var editingEventId: String?
    var editingGoogleEventId: String?

    var calendarId: String
    var title: String
    var isAllDay: Bool
    var start: Date
    var end: Date
    var selectedDays: Set<LocalDay>
    var recurrence: RecurrenceRule
    var reminderMinutes: [Int]
    var location: String
    var urlString: String
    var notes: String

    init(
        calendarId: String,
        startDay: LocalDay,
        calendar: Calendar = .current
    ) {
        self.calendarId = calendarId
        title = ""
        isAllDay = false
        let dayDate = startDay.date(calendar: calendar) ?? Date()
        start = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: dayDate) ?? dayDate
        end = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: dayDate) ?? dayDate
        selectedDays = [startDay]
        recurrence = .none
        reminderMinutes = []
        location = ""
        urlString = ""
        notes = ""
        editingEventId = nil
        editingGoogleEventId = nil
    }

    convenience init(from event: CalendarEvent, calendar: Calendar = .current) {
        self.init(calendarId: event.calendarId, startDay: LocalDay(event.start, calendar: calendar))
        editingEventId = event.id
        editingGoogleEventId = event.googleEventId
        title = event.title == "(タイトルなし)" ? "" : event.title
        isAllDay = event.isAllDay
        start = event.start
        end = event.isAllDay ? max(event.end, event.start) : event.end
        selectedDays = [LocalDay(event.start, calendar: calendar)]
        recurrence = .none
        reminderMinutes = event.reminderMinutes
        location = event.location ?? ""
        urlString = event.url?.absoluteString ?? ""
        notes = event.notes ?? ""
    }

    var isEditing: Bool { editingEventId != nil }

    var multiDaySummary: String {
        let sorted = selectedDays.sorted()
        guard sorted.count > 1 else { return "なし" }
        return sorted.map { shortDay($0) }.joined(separator: "、")
    }

    var recurrenceSummary: String {
        recurrence.summary(start: LocalDay(start))
    }

    var alarmSummary: String {
        guard !reminderMinutes.isEmpty else { return "なし" }
        return reminderMinutes.sorted().map { formatOffset($0) }.joined(separator: "、")
    }

    private func shortDay(_ day: LocalDay) -> String {
        guard let date = day.date() else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日"
        return f.string(from: date)
    }

    private func formatOffset(_ minutes: Int) -> String {
        if minutes >= 24 * 60 {
            return "\(minutes / (24 * 60))日前"
        }
        if minutes >= 60 {
            return "\(minutes / 60)時間前"
        }
        return "\(minutes)分前"
    }

    // MARK: - Mutual exclusion (複数日 ⇔ 繰り返し)

    func applySelectedDays(_ days: Set<LocalDay>) {
        selectedDays = days.isEmpty ? [LocalDay(start)] : days
        if selectedDays.count > 1 {
            recurrence = .none
        }
    }

    func applyRecurrence(_ rule: RecurrenceRule) {
        recurrence = rule
        if rule.isActive {
            let startDay = LocalDay(start)
            selectedDays = [startDay]
        }
    }

    /// Persistence shape for Google API (high level).
    enum SaveShape {
        case single
        case rdates(Set<LocalDay>)
        case recurrence(RecurrenceRule)
    }

    var saveShape: SaveShape {
        if recurrence.isActive {
            return .recurrence(recurrence)
        }
        if selectedDays.count > 1 {
            return .rdates(selectedDays)
        }
        return .single
    }
}
