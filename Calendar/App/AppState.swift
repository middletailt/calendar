import Foundation
import Observation

@Observable
final class AppState {
    var eventStore: EventStore
    var calendarStore: SubscribedCalendarStore

    init(eventStore: EventStore = EventStore(), calendarStore: SubscribedCalendarStore = .preview) {
        self.eventStore = eventStore
        self.calendarStore = calendarStore
    }
}
