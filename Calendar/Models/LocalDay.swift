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
}
