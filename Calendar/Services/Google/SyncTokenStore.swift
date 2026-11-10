import Foundation

enum SyncTokenStore {
    private static let defaults = UserDefaults.standard
    private static let prefix = "google_calendar_sync_token_"

    static func token(for calendarId: String) -> String? {
        defaults.string(forKey: prefix + calendarId)
    }

    static func set(_ token: String?, for calendarId: String) {
        let key = prefix + calendarId
        if let token {
            defaults.set(token, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    static func clearAll(for calendarIds: [String]) {
        for id in calendarIds {
            defaults.removeObject(forKey: prefix + id)
        }
    }
}
