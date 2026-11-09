import Foundation
import SwiftUI

struct CalendarEvent: Identifiable, Hashable {
    var id: String
    var googleEventId: String?
    var calendarId: String
    var title: String
    var isAllDay: Bool
    var start: Date
    var end: Date
    var location: String?
    var url: URL?
    var notes: String?
    var syncState: SyncState
    var color: Color

    var localDay: LocalDay { LocalDay(start) }

    func occurs(on day: LocalDay, calendar: Calendar = .current) -> Bool {
        let eventDay = LocalDay(start, calendar: calendar)
        if isAllDay {
            let endDay = LocalDay(end, calendar: calendar)
            return day >= eventDay && day < endDay
        }
        return eventDay == day
    }
}
