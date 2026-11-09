import SwiftUI

struct MainCalendarView: View {
    @Environment(AppState.self) private var appState
    @State private var visibleMonth = YearMonth(year: 2027, month: 3)
    @State private var selectedDay: LocalDay?
    @State private var isDaySheetPresented = false
    @State private var showNewEvent = false
    @State private var showSettings = false

    private let syncService: GoogleCalendarSyncing = StubGoogleCalendarSync()
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var visibleCalendarIds: Set<String> {
        Set(appState.calendarStore.calendars.filter(\.isVisible).map(\.id))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    header
                    weekdayHeader
                    monthGrid
                        .padding(.horizontal, 4)
                    Spacer(minLength: 0)
                }
                .background(Color(red: 0.93, green: 0.93, blue: 0.96))

                if isDaySheetPresented, let selectedDay {
                    DayEventsSheet(
                        day: selectedDay,
                        events: appState.eventStore.events(on: selectedDay, visibleCalendarIds: visibleCalendarIds),
                        onClose: { isDaySheetPresented = false },
                        onAddEvent: {
                            showNewEvent = true
                        }
                    )
                    .transition(.move(edge: .bottom))
                }

                bottomBar
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showNewEvent) {
                newEventEditor
            }
            .sheet(isPresented: $showSettings) {
                SettingsPlaceholderView()
            }
        }
    }

    private var header: some View {
        HStack {
            Text(visibleMonthTitle)
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            HStack(spacing: 12) {
                Button {} label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.primary)
                }
                Button { showSettings = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.8), in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var visibleMonthTitle: String {
        var comps = DateComponents()
        comps.year = visibleMonth.year
        comps.month = visibleMonth.month
        comps.day = 1
        guard let date = Calendar.current.date(from: comps) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月"
        return f.string(from: date)
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(Array(["日", "月", "火", "水", "木", "金", "土"].enumerated()), id: \.offset) { index, label in
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(weekdayColor(index))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    private func weekdayColor(_ index: Int) -> Color {
        switch index {
        case 0: .red
        case 6: .blue
        default: .secondary
        }
    }

    private var monthGrid: some View {
        let days = MonthGridBuilder.days(for: visibleMonth)
        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(days) { cell in
                MonthDayCell(
                    day: cell.day,
                    isInMonth: cell.isInDisplayedMonth,
                    isSelected: selectedDay == cell.day,
                    eventTitles: appState.eventStore.titlesForMonthCell(
                        day: cell.day,
                        visibleCalendarIds: visibleCalendarIds
                    )
                )
                .onTapGesture {
                    selectedDay = cell.day
                    withAnimation(.easeOut(duration: 0.22)) {
                        isDaySheetPresented = true
                    }
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var bottomBar: some View {
        HStack {
            Button {
                visibleMonth = visibleMonth.addingMonths(-1)
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3)
                    .frame(width: 52, height: 52)
                    .background(Color.white, in: Circle())
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            }
            Spacer()
            Button {
                if selectedDay == nil {
                    selectedDay = LocalDay(Date())
                }
                showNewEvent = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color(red: 0.15, green: 0.28, blue: 0.55), in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var newEventEditor: some View {
        let day = selectedDay ?? LocalDay(Date())
        EventEditorView(
            draft: EventDraft(
                calendarId: appState.calendarStore.defaultCalendarId,
                startDay: day
            ),
            calendarStore: appState.calendarStore,
            onCancel: { showNewEvent = false },
            onSave: { draft in
                if let cal = appState.calendarStore.calendar(id: draft.calendarId) {
                    appState.eventStore.add(from: draft, calendar: cal, sync: syncService)
                }
                showNewEvent = false
            }
        )
    }
}

#Preview {
    MainCalendarView()
        .environment(AppState())
}
