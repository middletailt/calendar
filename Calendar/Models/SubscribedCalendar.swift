import Foundation
import SwiftUI

struct SubscribedCalendar: Identifiable, Hashable {
    var id: String
    var title: String
    var color: Color
    var isVisible: Bool
    var canWrite: Bool
    var syncToken: String?
}

@Observable
final class SubscribedCalendarStore {
  var calendars: [SubscribedCalendar]

  init(calendars: [SubscribedCalendar]) {
    self.calendars = calendars
  }

  var defaultCalendarId: String {
    calendars.first(where: \.canWrite)?.id ?? calendars[0].id
  }

  func calendar(id: String) -> SubscribedCalendar? {
    calendars.first { $0.id == id }
  }

  static let preview: SubscribedCalendarStore = {
    SubscribedCalendarStore(calendars: [
      SubscribedCalendar(id: "schedule", title: "スケジュール", color: .blue, isVisible: true, canWrite: true, syncToken: nil),
      SubscribedCalendar(id: "work", title: "仕事", color: .orange, isVisible: true, canWrite: true, syncToken: nil),
    ])
  }()
}
