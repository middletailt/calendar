import SwiftUI

struct EventEditorView: View {
    @Bindable var draft: EventDraft
    var calendarStore: SubscribedCalendarStore
    var onCancel: () -> Void
    var onSave: (EventDraft) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    calendarCard
                    titleCard
                    dateTimeCard
                    optionsCard
                    detailsCard
                }
                .padding(16)
            }
            .background(CalendarTheme.canvasBackground)
            .navigationTitle(draft.isEditing ? "予定を編集" : "新しい予定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { onCancel() } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { onSave(draft) } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.multicolor)
                            .foregroundStyle(.blue)
                            .font(.title2)
                    }
                }
            }
        }
    }

    private var calendarCard: some View {
        NavigationLink {
            CalendarPickerView(
                calendars: calendarStore.calendars.filter(\.canWrite),
                selection: $draft.calendarId
            )
        } label: {
            cardRow(title: "カレンダー") {
                HStack(spacing: 8) {
                    if let cal = calendarStore.calendar(id: draft.calendarId) {
                        Circle().fill(cal.color).frame(width: 10, height: 10)
                        Text(cal.title)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var titleCard: some View {
        card {
            TextField("タイトル", text: $draft.title)
                .textFieldStyle(.plain)
        }
    }

    private var dateTimeCard: some View {
        card {
            Toggle("終日予定", isOn: $draft.isAllDay)
            LabeledRow(label: "開始") {
                DatePicker("", selection: $draft.start, displayedComponents: draft.isAllDay ? .date : [.date, .hourAndMinute])
                    .labelsHidden()
            }
            Divider()
            LabeledRow(label: "終了") {
                DatePicker("", selection: $draft.end, displayedComponents: draft.isAllDay ? .date : [.date, .hourAndMinute])
                    .labelsHidden()
            }
        }
    }

    private var optionsCard: some View {
        card {
            NavigationLink {
                MultiDayPickerView(draft: draft)
            } label: {
                menuRow(title: "複数日", value: draft.multiDaySummary)
            }
            .buttonStyle(.plain)
            Divider()
            NavigationLink {
                RecurrenceSettingsView(draft: draft)
            } label: {
                menuRow(title: "繰り返し", value: draft.recurrenceSummary)
            }
            .buttonStyle(.plain)
            Divider()
            NavigationLink {
                ReminderSettingsView(reminderMinutes: $draft.reminderMinutes)
            } label: {
                menuRow(title: "通知アラーム", value: draft.alarmSummary)
            }
            .buttonStyle(.plain)
        }
    }

    private var detailsCard: some View {
        card {
            TextField("場所", text: $draft.location)
            Divider()
            TextField("URL", text: $draft.urlString)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            Divider()
            TextField("メモ", text: $draft.notes, axis: .vertical)
                .lineLimit(3 ... 6)
        }
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CalendarTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    private func cardRow<Trailing: View>(title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Text(title)
            Spacer()
            trailing()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CalendarTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    private func menuRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(value == "なし" ? .tertiary : .secondary)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

struct LabeledRow<Content: View>: View {
    var label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 44, alignment: .leading)
            content
        }
    }
}

struct CalendarPickerView: View {
    var calendars: [SubscribedCalendar]
    @Binding var selection: String

    var body: some View {
        List(calendars) { cal in
            Button {
                selection = cal.id
            } label: {
                HStack {
                    Circle().fill(cal.color).frame(width: 12, height: 12)
                    Text(cal.title)
                    Spacer()
                    if selection == cal.id {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
        .navigationTitle("カレンダー")
    }
}

