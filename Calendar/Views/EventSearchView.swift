import SwiftUI

struct EventSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var visibleCalendarIds: Set<String>
    var onSelectEvent: (CalendarEvent) -> Void

    @State private var query = ""

    private var results: [CalendarEvent] {
        appState.eventStore.search(query: query, visibleCalendarIds: visibleCalendarIds)
    }

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("タイトル・場所・メモで検索できます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if results.isEmpty {
                    Text("一致する予定がありません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(results) { event in
                        Button {
                            onSelectEvent(event)
                        } label: {
                            EventSearchResultRow(
                                event: event,
                                calendarTitle: appState.calendarStore.calendar(id: event.calendarId)?.title ?? ""
                            )
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "予定を検索")
            .navigationTitle("検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

private struct EventSearchResultRow: View {
    var event: CalendarEvent
    var calendarTitle: String

    private var subtitle: String {
        let day = LocalDay(event.start)
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = event.isAllDay ? "yyyy年M月d日（E）・終日" : "yyyy年M月d日（E） HH:mm"
        if event.isAllDay {
            return f.string(from: event.start)
        }
        return f.string(from: event.start)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.color)
                .frame(width: 4)
                .padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.body)
                    .foregroundStyle(CalendarTheme.ink)
                Text("\(subtitle) · \(calendarTitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}
