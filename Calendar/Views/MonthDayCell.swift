import SwiftUI

struct MonthDayCell: View {
    @Environment(\.colorScheme) private var colorScheme

    var day: LocalDay
    var isInMonth: Bool
    var isToday: Bool
    var isSelected: Bool
    var eventLines: [MonthCellEventLine]
    var showsTrailingDivider = true
    var showsLeadingDivider = false

    private let contentInset = DayCellSelectionStyle.contentInset

    private var hasHoliday: Bool {
        eventLines.contains(where: \.isHoliday)
    }

    private var cellBackground: Color {
        if isToday {
            return CalendarTheme.todayCellFill(colorScheme)
        }
        return CalendarTheme.cellBackground
    }

    private var dayNumberColor: Color {
        if !isInMonth { return CalendarTheme.inkMuted.opacity(0.7) }
        if hasHoliday { return CalendarTheme.holiday }
        switch day.weekdayIndex {
        case 1: return CalendarTheme.sunday
        case 7: return CalendarTheme.saturday
        default: return CalendarTheme.ink
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(day.day)")
                .font(.subheadline)
                .foregroundStyle(dayNumberColor)
                .padding(.bottom, 2)

            ForEach(eventLines) { line in
                switch line.style {
                case .band:
                    MonthDayCellBand(title: line.title, color: line.accentColor)
                        .padding(.horizontal, -DayCellSelectionStyle.contentInset)
                case .compact:
                    MonthDayCellCompactTitle(title: line.title, color: line.accentColor)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(contentInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cellBackground)
        .overlay(alignment: .trailing) {
            if showsTrailingDivider {
                Rectangle()
                    .fill(CalendarTheme.gridSeparator.opacity(0.6))
                    .frame(width: 0.5)
            }
        }
        .overlay(alignment: .leading) {
            if showsLeadingDivider {
                Rectangle()
                    .fill(CalendarTheme.gridSeparator.opacity(0.6))
                    .frame(width: 0.5)
            }
        }
        .overlay {
            if isSelected {
                DayCellSelectionOutline()
            }
        }
    }
}

private enum MonthDayCellBandMetrics {
    static let font: Font = .caption2
    static let horizontalPadding: CGFloat = 3
    static let verticalPadding: CGFloat = 1
    static let cornerRadius: CGFloat = 3
}

private struct MonthDayCellBand: View {
    var title: String
    var color: Color

    var body: some View {
        ClippingSingleLineText(text: title, font: MonthDayCellBandMetrics.font, color: .white)
            .padding(.horizontal, MonthDayCellBandMetrics.horizontalPadding)
            .padding(.vertical, MonthDayCellBandMetrics.verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color, in: RoundedRectangle(cornerRadius: MonthDayCellBandMetrics.cornerRadius))
    }
}

private struct MonthDayCellCompactTitle: View {
    var title: String
    var color: Color

    var body: some View {
        ClippingSingleLineText(text: title, color: color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum DayCellSelectionStyle {
    static let lineWidth: CGFloat = 2
    /// 選択の有無に関わらず一定のセル内余白
    static let contentInset: CGFloat = 3
}

/// 枠の外側はグリッド境界と一致（インセットなし）。
private struct DayCellSelectionOutline: View {
    var body: some View {
        Rectangle()
            .strokeBorder(CalendarTheme.accent, lineWidth: DayCellSelectionStyle.lineWidth)
            .allowsHitTesting(false)
    }
}

/// グリッドの空セル用プレースホルダ。
struct MonthDayCellPlaceholder: View {
    var showsTrailingDivider = true
    var showsLeadingDivider = false

    var body: some View {
        Rectangle()
            .fill(CalendarTheme.cellBackground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .trailing) {
                if showsTrailingDivider {
                    Rectangle()
                        .fill(CalendarTheme.gridSeparator.opacity(0.6))
                        .frame(width: 0.5)
                }
            }
            .overlay(alignment: .leading) {
                if showsLeadingDivider {
                    Rectangle()
                        .fill(CalendarTheme.gridSeparator.opacity(0.6))
                        .frame(width: 0.5)
                }
            }
    }
}
