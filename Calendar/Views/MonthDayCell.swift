import SwiftUI

struct MonthDayCell: View {
    var day: LocalDay
    var isInMonth: Bool
    var isSelected: Bool
    var eventTitles: [String]

    private var dayNumberColor: Color {
        if !isInMonth { return Color.secondary.opacity(0.45) }
        switch day.weekdayIndex {
        case 1: return .red
        case 7: return .blue
        default: return .primary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(day.day)")
                .font(.subheadline)
                .foregroundStyle(dayNumberColor)
            ForEach(eventTitles.prefix(2), id: \.self) { title in
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        .padding(6)
        .background(Color.white)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(red: 0.15, green: 0.28, blue: 0.55), lineWidth: 2)
            }
        }
        .overlay(Rectangle().stroke(Color(white: 0.9), lineWidth: 0.5))
    }
}
