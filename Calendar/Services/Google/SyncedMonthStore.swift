import Foundation

/// カレンダーごとに `events.list` で取得済みの年月を記録する（月単位のオンデマンド同期用）。
enum SyncedMonthStore {
    private static let defaults = UserDefaults.standard
    private static let prefix = "google_synced_month_"

    static func isSynced(calendarId: String, month: YearMonth) -> Bool {
        defaults.bool(forKey: storageKey(calendarId: calendarId, month: month))
    }

    static func isRangeFullySynced(calendarId: String, center: YearMonth, radiusMonths: Int) -> Bool {
        for delta in -radiusMonths ... radiusMonths {
            let month = center.addingMonths(delta)
            if !isSynced(calendarId: calendarId, month: month) {
                return false
            }
        }
        return true
    }

    static func markRangeSynced(calendarId: String, center: YearMonth, radiusMonths: Int) {
        for delta in -radiusMonths ... radiusMonths {
            markSynced(calendarId: calendarId, month: center.addingMonths(delta))
        }
    }

    static func markSynced(calendarId: String, month: YearMonth) {
        defaults.set(true, forKey: storageKey(calendarId: calendarId, month: month))
    }

    static func clearAll(for calendarIds: [String]) {
        let keys = defaults.dictionaryRepresentation().keys
        for calendarId in calendarIds {
            let head = prefix + calendarId + ":"
            for key in keys where key.hasPrefix(head) {
                defaults.removeObject(forKey: key)
            }
        }
    }

    private static func storageKey(calendarId: String, month: YearMonth) -> String {
        prefix + "\(calendarId):\(month.year)-\(month.month)"
    }
}
