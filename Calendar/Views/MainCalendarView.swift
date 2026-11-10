import SwiftUI

struct MainCalendarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var visibleMonth = YearMonth.current()
    @State private var selectedDay: LocalDay? = LocalDay(Date())
    @State private var isDaySheetPresented = false
    @State private var showNewEvent = false
    @State private var showSettings = false
    @State private var showMonthPicker = false
    @State private var showSearch = false
    @State private var presentedEvent: CalendarEvent?
    @State private var editingEvent: CalendarEvent?
    @State private var pagerPageModels: (MonthGridPageModel, MonthGridPageModel, MonthGridPageModel)?
    @AppStorage(MonthPagerStyle.storageKey) private var monthPagerStyleRaw = MonthPagerStyle.swiftUIPager.rawValue

    private let daySheetAnimation: Animation = .easeOut(duration: 0.32)

    private var monthPagerStyle: MonthPagerStyle {
        MonthPagerStyle(rawValue: monthPagerStyleRaw) ?? .swiftUIPager
    }

    private var visibleCalendarIds: Set<String> {
        Set(appState.calendarStore.calendars.filter(\.isVisible).map(\.id))
    }

    private var visibleHolidayCalendarIds: Set<String> {
        Set(
            appState.calendarStore.calendars
                .filter { $0.isJapaneseHolidayCalendar && $0.isVisible }
                .map(\.id)
        )
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        header
                        calendarBlock
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    .background(CalendarTheme.canvasBackground)

                    if isDaySheetPresented, let selectedDay {
                        DayEventsSheet(
                            day: selectedDay,
                            events: appState.eventStore.events(on: selectedDay, visibleCalendarIds: visibleCalendarIds),
                            onClose: dismissDaySheet,
                            onAddEvent: {
                                showNewEvent = true
                            },
                            onSelectEvent: { event in
                                presentedEvent = event
                            }
                        )
                        .frame(height: geometry.size.height / 3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom))
                        .zIndex(1)
                    }
                }
                .animation(daySheetAnimation, value: isDaySheetPresented)
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomToolbar
            }
            .sheet(isPresented: $showNewEvent) {
                newEventEditor
            }
            .sheet(isPresented: $showSearch) {
                EventSearchView(visibleCalendarIds: visibleCalendarIds) { event in
                    showSearch = false
                    presentedEvent = event
                }
            }
            .sheet(item: $presentedEvent) { event in
                eventDetailSheet(for: event)
            }
            .sheet(item: $editingEvent) { event in
                eventEditor(for: event)
            }
            .sheet(isPresented: $showSettings) {
                GoogleSettingsView()
            }
            .sheet(isPresented: $showMonthPicker) {
                MonthYearPickerSheet(current: visibleMonth) { newMonth in
                    setVisibleMonth(newMonth)
                }
            }
            .tint(CalendarTheme.accent)
            .task {
                _ = await appState.localNotifications.requestAuthorizationIfNeeded()
                if appState.googleSync.isSignedIn {
                    try? await appState.googleSync.syncAllCalendars()
                    appState.eventStore.refreshMemoryCache(center: visibleMonth)
                    rebuildPagerPageModels()
                    await prefetchMonthsAroundVisible()
                }
                await appState.rebuildNotifications()
            }
            .onAppear {
                appState.eventStore.refreshMemoryCache(center: visibleMonth)
                rebuildPagerPageModels()
            }
            .onChange(of: visibleMonth) { _, newMonth in
                appState.eventStore.refreshMemoryCache(center: newMonth)
                rebuildPagerPageModels()
            }
            .onChange(of: selectedDay) { _, _ in rebuildPagerPageModels() }
            .onChange(of: appState.eventStore.events.count) { _, _ in
                appState.eventStore.refreshMemoryCache(center: visibleMonth)
                rebuildPagerPageModels()
            }
        }
    }

    private func setVisibleMonth(_ newMonth: YearMonth) {
        guard newMonth != visibleMonth else { return }
        visibleMonth = newMonth
        rebuildPagerPageModels()
        Task { await prefetchMonthsAroundVisible() }
    }

    private func rebuildPagerPageModels() {
        let today = LocalDay(Date())
        pagerPageModels = (
            makePagerPageModel(for: visibleMonth.addingMonths(-1), today: today),
            makePagerPageModel(for: visibleMonth, today: today),
            makePagerPageModel(for: visibleMonth.addingMonths(1), today: today)
        )
    }

    private func makePagerPageModel(for month: YearMonth, today: LocalDay) -> MonthGridPageModel {
        MonthGridPageModel(
            month: month,
            days: MonthGridBuilder.days(for: month),
            linesByDay: appState.eventStore.eventLinesByDay(
                for: month,
                visibleCalendarIds: visibleCalendarIds,
                holidayCalendarIds: visibleHolidayCalendarIds
            ),
            selectedDay: selectedDay,
            today: today
        )
    }

    private func prefetchMonthsAroundVisible() async {
        guard appState.googleSync.isSignedIn else { return }
        let center = visibleMonth
        await appState.googleSync.ensureSynced(for: center)
        await appState.googleSync.ensureSynced(for: center.addingMonths(-1))
        await appState.googleSync.ensureSynced(for: center.addingMonths(1))
    }

    private func presentDaySheet() {
        withAnimation(daySheetAnimation) {
            isDaySheetPresented = true
        }
    }

    private func dismissDaySheet() {
        withAnimation(daySheetAnimation) {
            isDaySheetPresented = false
        }
    }

    private var header: some View {
        HStack {
            Button {
                showMonthPicker = true
            } label: {
                Text(monthTitle(for: visibleMonth))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(CalendarTheme.ink)
            }
            .buttonStyle(.plain)

            Spacer()
            HStack(spacing: 12) {
                Button { showSearch = true } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(CalendarTheme.ink)
                }
                Button { showSettings = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(CalendarTheme.ink)
                        if settingsBadgeVisible {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 4, y: -4)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(CalendarTheme.elevatedControl.opacity(0.95), in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func monthTitle(for month: YearMonth) -> String {
        var comps = DateComponents()
        comps.year = month.year
        comps.month = month.month
        comps.day = 1
        guard let date = Calendar.current.date(from: comps) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月"
        return f.string(from: date)
    }

    @ViewBuilder
    private func monthPagerView(
        models: (MonthGridPageModel, MonthGridPageModel, MonthGridPageModel)
    ) -> some View {
        let onCommit: (YearMonth) -> Void = { _ in
            rebuildPagerPageModels()
            Task { await prefetchMonthsAroundVisible() }
        }
        let onDay: (LocalDay) -> Void = { day in
            selectedDay = day
            presentDaySheet()
        }

        switch monthPagerStyle {
        case .swiftUIPager:
            MonthCalendarPager(
                prev: models.0,
                center: models.1,
                next: models.2,
                visibleMonth: $visibleMonth,
                onMonthCommitted: onCommit,
                onSelectDay: onDay
            )
        case .uiScrollView:
            MonthUIKitScrollPager(
                prev: models.0,
                center: models.1,
                next: models.2,
                visibleMonth: $visibleMonth,
                onMonthCommitted: onCommit,
                onSelectDay: onDay
            )
        }
    }

    private var calendarBlock: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(CalendarTheme.gridSeparator)
                .frame(height: 0.5)

            if let pagerPageModels {
                monthPagerView(models: pagerPageModels)
                    .id(monthPagerStyle)
            }

            Rectangle()
                .fill(CalendarTheme.gridSeparator)
                .frame(height: 0.5)
        }
        .background(CalendarTheme.cardBackground)
    }

    private var bottomToolbar: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                if selectedDay == nil {
                    selectedDay = LocalDay(Date())
                }
                showNewEvent = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(CalendarTheme.fabForeground)
                    .frame(width: 52, height: 52)
                    .background(CalendarTheme.accent, in: Circle())
            }
            .accessibilityLabel("新しい予定")
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(CalendarTheme.canvasBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(CalendarTheme.gridSeparator.opacity(0.35))
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func eventDetailSheet(for event: CalendarEvent) -> some View {
        let calendar = appState.calendarStore.calendar(id: event.calendarId)
        EventDetailView(
            event: event,
            calendarTitle: calendar?.title ?? event.calendarId,
            canEdit: calendar?.canWrite == true,
            onEdit: {
                presentedEvent = nil
                editingEvent = event
            },
            onDelete: {
                appState.eventStore.delete(event: event, sync: appState.googleSync)
                Task { await appState.rebuildNotifications() }
            }
        )
    }

    @ViewBuilder
    private func eventEditor(for event: CalendarEvent) -> some View {
        EventEditorView(
            draft: EventDraft(from: event),
            calendarStore: appState.calendarStore,
            onCancel: { editingEvent = nil },
            onSave: { draft in
                if let cal = appState.calendarStore.calendar(id: draft.calendarId) {
                    appState.eventStore.update(from: draft, calendar: cal, sync: appState.googleSync)
                }
                Task { await appState.rebuildNotifications() }
                editingEvent = nil
            }
        )
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
                    appState.eventStore.add(from: draft, calendar: cal, sync: appState.googleSync)
                }
                Task { await appState.rebuildNotifications() }
                showNewEvent = false
            }
        )
    }

    private var settingsBadgeVisible: Bool {
        appState.googleSync.lastError != nil || (!appState.googleSync.isSignedIn && GoogleOAuthConfig.isConfigured)
    }
}

#Preview("Light") {
    MainCalendarView()
        .environment(AppState.preview)
}

#Preview("Dark") {
    MainCalendarView()
        .environment(AppState.preview)
        .preferredColorScheme(.dark)
}
