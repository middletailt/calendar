import Foundation
import SwiftUI
import UIKit

struct MonthGridDay: Identifiable, Hashable {
    var id: String { "\(day.year)-\(day.month)-\(day.day)" }
    var day: LocalDay
    var isInDisplayedMonth: Bool
}

enum MonthGridBuilder {
    /// Builds 5–6 rows (35 or 42 cells) starting Sunday.
    static func days(for month: YearMonth, calendar: Calendar = .current) -> [MonthGridDay] {
        var comps = DateComponents()
        comps.year = month.year
        comps.month = month.month
        comps.day = 1
        guard let firstOfMonth = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leading = weekday - 1

        guard let gridStart = calendar.date(byAdding: .day, value: -leading, to: firstOfMonth) else {
            return []
        }

        let totalCells = range.count + leading <= 35 ? 35 : 42
        return (0 ..< totalCells).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else { return nil }
            let day = LocalDay(date, calendar: calendar)
            let inMonth = calendar.component(.month, from: date) == month.month
                && calendar.component(.year, from: date) == month.year
            return MonthGridDay(day: day, isInDisplayedMonth: inMonth)
        }
    }
}

// MARK: - ライト / ダーク両対応のカレンダー用カラー

enum CalendarTheme {
    static let canvasBackground = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let cellBackground = Color(uiColor: .systemBackground)
    static let elevatedControl = Color(uiColor: .secondarySystemBackground)

    static let ink = Color.primary
    static let inkSecondary = Color.secondary
    static let inkMuted = Color(uiColor: .tertiaryLabel)

    static let sunday = Color.red
    static let saturday = Color.blue
    static let holiday = Color.red

    static let accent = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.38, green: 0.58, blue: 1.0, alpha: 1)
                : UIColor(red: 0.15, green: 0.28, blue: 0.55, alpha: 1)
        }
    )

    static let gridSeparator = Color(uiColor: .separator)
    static let fabForeground = Color.white

    static func floatingShadowOpacity(_ scheme: ColorScheme) -> Double {
        scheme == .dark ? 0.45 : 0.12
    }

    static func multiDaySelectionFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? accent.opacity(0.35) : accent.opacity(0.18)
    }

    static func todayCellFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? accent.opacity(0.24) : accent.opacity(0.14)
    }
}
