import Foundation

enum RecurrenceFrequency: String, CaseIterable, Identifiable, Codable {
    case none
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "なし"
        case .daily: "毎日"
        case .weekly: "毎週"
        case .monthly: "毎月"
        case .yearly: "毎年"
        }
    }
}

enum RecurrenceEnd: Equatable, Hashable, Codable {
    case never
    case count(Int)
    case until(LocalDay)
}

struct RecurrenceRule: Equatable, Hashable, Codable {
    var frequency: RecurrenceFrequency
    var interval: Int
    var end: RecurrenceEnd

    static let none = RecurrenceRule(frequency: .none, interval: 1, end: .never)

    var isActive: Bool { frequency != .none }

    func summary(start: LocalDay) -> String {
        guard frequency != .none else { return "なし" }
        var parts = [frequency.title]
        if interval > 1 {
            parts.append("・\(interval)ごと")
        }
        switch end {
        case .never:
            break
        case .count(let n):
            parts.append("・\(n)回")
        case .until(let day):
            parts.append("・\(shortDay(day))まで")
        }
        return parts.joined(separator: "")
    }

    private func shortDay(_ day: LocalDay) -> String {
        guard let date = day.date() else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/M/d"
        return f.string(from: date)
    }

    /// RFC5545 RRULE line (without prefix).
    func rruleLine(until utcFormatter: ISO8601DateFormatter) -> String? {
        guard frequency != .none else { return nil }
        let freq: String
        switch frequency {
        case .none: return nil
        case .daily: freq = "DAILY"
        case .weekly: freq = "WEEKLY"
        case .monthly: freq = "MONTHLY"
        case .yearly: freq = "YEARLY"
        }
        var parts = ["FREQ=\(freq)"]
        if interval > 1 {
            parts.append("INTERVAL=\(interval)")
        }
        switch end {
        case .never:
            break
        case .count(let n):
            parts.append("COUNT=\(n)")
        case .until(let day):
            guard let date = day.date() else { break }
            var utc = Calendar(identifier: .gregorian)
            utc.timeZone = TimeZone(secondsFromGMT: 0)!
            let endOfDay = utc.date(bySettingHour: 23, minute: 59, second: 59, of: date)!
            let s = utcFormatter.string(from: endOfDay).replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "")
            parts.append("UNTIL=\(s)")
        }
        return parts.joined(separator: ";")
    }
}
