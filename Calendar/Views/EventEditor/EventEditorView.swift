import SwiftUI

struct EventEditorView: View {
    @Bindable var draft: EventDraft
    var calendarStore: SubscribedCalendarStore
    /// 読み取り専用カレンダーの予定（編集・保存不可）
    var isReadOnly = false
    var onCancel: () -> Void
    var onSave: (EventDraft) -> Void
    var onDelete: (() -> Void)?
    /// 新規作成画面へ同内容を渡す（保存はユーザー操作）
    var onCopy: ((EventDraft) -> Void)?

    @State private var showDeleteConfirm = false

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
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 48, minHeight: 48)
                    }
                    .buttonStyle(.plain)
                }
                if !isReadOnly {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: { onSave(draft) }) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.largeTitle)
                                .symbolRenderingMode(.multicolor)
                                .foregroundStyle(.blue)
                                .frame(minWidth: 48, minHeight: 48)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if onCopy != nil || onDelete != nil {
                    ToolbarItem(placement: .bottomBar) {
                        HStack {
                            if onCopy != nil {
                                Button("コピー") {
                                    onCopy?(duplicateDraft())
                                }
                            }
                            Spacer()
                            if onDelete != nil {
                                Button("削除", role: .destructive) {
                                    showDeleteConfirm = true
                                }
                            }
                        }
                    }
                }
            }
            .confirmationDialog("この予定を削除しますか？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    onDelete?()
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    private var navigationTitle: String {
        if isReadOnly { return "予定" }
        return draft.isEditing ? "予定を編集" : "新しい予定"
    }

    private func duplicateDraft() -> EventDraft {
        var copy = draft
        copy.editingEventId = nil
        copy.editingGoogleEventId = nil
        return copy
    }

    private var calendarCard: some View {
        Group {
            if isReadOnly {
                cardRow(title: "カレンダー") {
                    HStack(spacing: 8) {
                        if let cal = calendarStore.calendar(id: draft.calendarId) {
                            Circle().fill(cal.color).frame(width: 10, height: 10)
                            Text(cal.title)
                        }
                    }
                }
            } else {
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
        }
    }

    private var titleCard: some View {
        card {
            TextField("タイトル", text: $draft.title)
                .textFieldStyle(.plain)
                .disabled(isReadOnly)
        }
    }

    private var dateTimeCard: some View {
        card {
            Toggle("終日予定", isOn: $draft.isAllDay)
                .disabled(isReadOnly)
            LabeledRow(label: "開始") {
                DatePicker("", selection: $draft.start, displayedComponents: draft.isAllDay ? .date : [.date, .hourAndMinute])
                    .labelsHidden()
                    .disabled(isReadOnly)
            }
            Divider()
            LabeledRow(label: "終了") {
                DatePicker("", selection: $draft.end, displayedComponents: draft.isAllDay ? .date : [.date, .hourAndMinute])
                    .labelsHidden()
                    .disabled(isReadOnly)
            }
        }
    }

    private var optionsCard: some View {
        card {
            if isReadOnly {
                menuRow(title: "複数日", value: draft.multiDaySummary)
                Divider()
                menuRow(title: "繰り返し", value: draft.recurrenceSummary)
                Divider()
                menuRow(title: "通知アラーム", value: draft.alarmSummary)
            } else {
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
    }

    private var detailsCard: some View {
        card {
            TextField("場所", text: $draft.location)
                .disabled(isReadOnly)
            Divider()
            TextField("URL", text: $draft.urlString)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .disabled(isReadOnly)
            Divider()
            TextField("メモ", text: $draft.notes, axis: .vertical)
                .lineLimit(3 ... 6)
                .disabled(isReadOnly)
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

