import SwiftUI

struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss

    var event: CalendarEvent
    var calendarTitle: String
    var canEdit: Bool
    var onEdit: () -> Void
    var onDelete: () -> Void

  @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(event.title)
                        .font(.title3.weight(.semibold))
                }
                Section("日時") {
                    LabeledContent("日付", value: dateLine)
                    LabeledContent("時間", value: timeLine)
                }
                Section("カレンダー") {
                    LabeledContent("カレンダー", value: calendarTitle)
                }
                if let location = event.location, !location.isEmpty {
                    Section("場所") {
                        Text(location)
                    }
                }
                if let url = event.url {
                    Section("URL") {
                        Link(url.absoluteString, destination: url)
                    }
                }
                if let notes = event.notes, !notes.isEmpty {
                    Section("メモ") {
                        Text(notes)
                            .textSelection(.enabled)
                    }
                }
                if !canEdit {
                    Section {
                        Text("この予定は読み取り専用のカレンダーにあります。編集・削除できません。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("予定の詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                if canEdit {
                    ToolbarItem(placement: .primaryAction) {
                        Button("編集", action: onEdit)
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Button("削除", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }
            }
            .confirmationDialog("この予定を削除しますか？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    private var dateLine: String {
        LocalDay(event.start).formattedLong()
    }

    private var timeLine: String {
        if event.isAllDay { return "終日" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "\(f.string(from: event.start)) 〜 \(f.string(from: event.end))"
    }
}
