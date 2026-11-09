import SwiftUI

struct DayEventsSheet: View {
    var day: LocalDay
    var events: [CalendarEvent]
    var onClose: () -> Void
    var onAddEvent: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(day.formattedLong())
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            if events.isEmpty {
                Text("予定はありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(events) { event in
                            DayEventRow(event: event)
                        }
                    }
                }
                .frame(maxHeight: 160)
            }

            Button(action: onAddEvent) {
                Label("予定を追加", systemImage: "plus")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(white: 0.94), in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.12), radius: 12, y: -4)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 80)
    }
}

struct DayEventRow: View {
    var event: CalendarEvent

  private var timeText: String {
        if event.isAllDay { return "終日" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "\(f.string(from: event.start))\n\(f.string(from: event.end))"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(timeText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .frame(width: 52)
            RoundedRectangle(cornerRadius: 2)
                .fill(event.color)
                .frame(width: 4)
                .padding(.vertical, 2)
            Text(event.title)
                .font(.body)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
