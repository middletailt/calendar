import Foundation

enum EventReminderPresets {
    static let maximumSelectionCount = 3

    static let options: [(minutes: Int, label: String)] = [
        (10, "10分前"),
        (30, "30分前"),
        (60, "1時間前"),
        (180, "3時間前"),
        (360, "6時間前"),
        (720, "12時間前"),
        (1_440, "1日前"),
        (4_320, "3日前"),
        (10_080, "7日前"),
    ]

    static func label(for minutes: Int) -> String? {
        options.first { $0.minutes == minutes }?.label
    }
}
