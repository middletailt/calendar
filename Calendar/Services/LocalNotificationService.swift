import Foundation
import UserNotifications

/// 予定の事前通知（ローカル通知）。APNs / Push Notifications capability は不要。
@MainActor
final class LocalNotificationService {
    nonisolated init() {}

    private let center = UNUserNotificationCenter.current()
    private let maxPending = 60

    private(set) var authorizationStatus: UNAuthorizationStatus?

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                await refreshAuthorizationStatus()
                return granted
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    func reschedule(events: [CalendarEvent]) async {
        let allowed = await requestAuthorizationIfNeeded()
        guard allowed else { return }

        center.removeAllPendingNotificationRequests()

        let now = Date()
        var requests: [UNNotificationRequest] = []

        for event in events {
            let offsets = event.reminderMinutes.isEmpty ? [] : event.reminderMinutes
            for minutes in offsets {
                guard let triggerDate = triggerDate(for: event, minutesBefore: minutes) else { continue }
                guard triggerDate > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = event.title
                content.body = notificationBody(for: event, minutesBefore: minutes)
                content.sound = .default

                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: triggerDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

                let id = notificationId(eventId: event.id, minutesBefore: minutes)
                requests.append(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }

        let sorted = requests.sorted {
            guard let d0 = ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate(),
                  let d1 = ($1.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() else {
                return false
            }
            return d0 < d1
        }

        for request in sorted.prefix(maxPending) {
            try? await center.add(request)
        }
    }

    private func triggerDate(for event: CalendarEvent, minutesBefore: Int) -> Date? {
        let anchor = event.isAllDay
            ? (Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: event.start) ?? event.start)
            : event.start
        return Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: anchor)
    }

    private func notificationBody(for event: CalendarEvent, minutesBefore: Int) -> String {
        if let location = event.location, !location.isEmpty {
            return location
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        if event.isAllDay {
            f.dateFormat = "M月d日 終日"
        } else {
            f.dateFormat = "M月d日 HH:mm 開始"
        }
        let when = f.string(from: event.start)
        if minutesBefore == 0 {
            return when
        }
        return "\(when)（\(offsetLabel(minutesBefore))）"
    }

    private func offsetLabel(_ minutes: Int) -> String {
        if minutes >= 24 * 60 { return "\(minutes / (24 * 60))日前" }
        if minutes >= 60 { return "\(minutes / 60)時間前" }
        return "\(minutes)分前"
    }

    private func notificationId(eventId: String, minutesBefore: Int) -> String {
        "event:\(eventId):before:\(minutesBefore)"
    }
}
