import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppState {
    var eventStore: EventStore
    var calendarStore: SubscribedCalendarStore
    let googleSync: GoogleCalendarSyncService
    let localNotifications = LocalNotificationService()
    let modelContainer: ModelContainer

    init(
        eventStore: EventStore? = nil,
        calendarStore: SubscribedCalendarStore? = nil,
        googleSync: GoogleCalendarSyncService = GoogleCalendarSyncService(),
        modelContainer: ModelContainer? = nil
    ) {
        let container = modelContainer ?? CalendarPersistence.makeContainer()
        self.modelContainer = container
        let context = ModelContext(container)
        OutboxStore.configure(context: context)

        self.eventStore = eventStore ?? EventStore(context: context)
        self.calendarStore = calendarStore ?? SubscribedCalendarStore(context: context)
        self.googleSync = googleSync
        for calendar in self.calendarStore.calendars {
            if let token = calendar.syncToken {
                SyncTokenStore.set(token, for: calendar.id)
            }
        }
        googleSync.configure(eventStore: self.eventStore, calendarStore: self.calendarStore) { [weak self] in
            Task { @MainActor in
                await self?.rebuildNotifications()
            }
        }
    }

    func rebuildNotifications() async {
        await localNotifications.reschedule(events: eventStore.eventsForNotificationScheduling())
    }

    static var preview: AppState {
        AppState(
            eventStore: EventStore(events: EventStore.previewEvents),
            calendarStore: .preview,
            modelContainer: CalendarPersistence.makePreviewContainer()
        )
    }
}
