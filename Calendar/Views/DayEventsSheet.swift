import SwiftUI

struct DayEventsSheet: View {
    @Environment(\.colorScheme) private var colorScheme

    var day: LocalDay
    var events: [CalendarEvent]
    var onClose: () -> Void
    var onAddEvent: () -> Void
    var onSelectEvent: (CalendarEvent) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(day.formattedLong())
                    .font(.headline)
                    .foregroundStyle(CalendarTheme.ink)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            if events.isEmpty {
                Text("予定はありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(events) { event in
                            Button {
                                onSelectEvent(event)
                            } label: {
                                DayEventRow(event: event)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Button(action: onAddEvent) {
                Label("予定を追加", systemImage: "plus")
                    .font(.body.weight(.medium))
                    .foregroundStyle(CalendarTheme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(CalendarTheme.elevatedControl, in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(CalendarTheme.cellBackground)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                topTrailingRadius: 16
            )
        )
        .shadow(color: .black.opacity(CalendarTheme.floatingShadowOpacity(colorScheme)), radius: 12, y: -4)
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
                .foregroundStyle(CalendarTheme.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
