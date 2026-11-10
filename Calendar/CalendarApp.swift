import SwiftUI

@main
struct CalendarApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainCalendarView()
                .environment(appState)
                .tint(CalendarTheme.accent)
        }
        .modelContainer(appState.modelContainer)
    }
}
