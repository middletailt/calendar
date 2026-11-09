import Foundation

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
