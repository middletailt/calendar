import Foundation

/// Calendar date without time-of-day, in a fixed time zone.
struct LocalDay: Hashable, Comparable, Codable {
    var year: Int
    var month: Int
    var day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        year = c.year!
        month = c.month!
        day = c.day!
    }

    func date(calendar: Calendar = .current) -> Date? {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return calendar.date(from: comps)
    }

    static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }

    var weekdayIndex: Int {
        guard let date = date() else { return 1 }
        return Calendar.current.component(.weekday, from: date)
    }

    func formattedYearMonth(calendar: Calendar = .current) -> String {
        guard let date = date(calendar: calendar) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月"
        return f.string(from: date)
    }

    func formattedLong(calendar: Calendar = .current) -> String {
        guard let date = date(calendar: calendar) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月d日(E)"
        return f.string(from: date)
    }
}

struct YearMonth: Hashable, Equatable {
    var year: Int
    var month: Int

    static func current(calendar: Calendar = .current) -> YearMonth {
        let comps = calendar.dateComponents([.year, .month], from: Date())
        return YearMonth(year: comps.year!, month: comps.month!)
    }

    /// 前後関係・スライド方向の判定用（1ヶ月 = 1）。
    var monthOrdinal: Int { year * 12 + month }

    func slideDirection(to other: YearMonth) -> MonthSlideDirection {
        other.monthOrdinal >= monthOrdinal ? .forward : .backward
    }

    func addingMonths(_ delta: Int, calendar: Calendar = .current) -> YearMonth {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let start = calendar.date(from: comps),
              let next = calendar.date(byAdding: .month, value: delta, to: start) else {
            return self
        }
        let c = calendar.dateComponents([.year, .month], from: next)
        return YearMonth(year: c.year!, month: c.month!)
    }

    func startDate(calendar: Calendar = .current) -> Date? {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        return calendar.date(from: comps)
    }

    /// `timeMax` 用（当月末の翌日 0:00 = 当月を含む）
    func endDateExclusive(calendar: Calendar = .current) -> Date? {
        guard let start = startDate(calendar: calendar),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: start) else {
            return nil
        }
        return nextMonth
    }

    /// 中心月 ± `radiusMonths` の `timeMin` / `timeMax`（計 2×radius+1 ヶ月）。
    static func syncTimeRange(
        center: YearMonth,
        radiusMonths: Int,
        calendar: Calendar = .current
    ) -> (timeMin: Date, timeMax: Date)? {
        let first = center.addingMonths(-radiusMonths, calendar: calendar)
        let last = center.addingMonths(radiusMonths, calendar: calendar)
        guard let timeMin = first.startDate(calendar: calendar),
              let timeMax = last.endDateExclusive(calendar: calendar) else {
            return nil
        }
        return (timeMin, timeMax)
    }
}

enum MonthSlideDirection {
    case forward
    case backward
}
