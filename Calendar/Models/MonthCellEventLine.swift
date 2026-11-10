import SwiftUI

struct MonthCellEventLine: Identifiable, Hashable {
    var id: String
    var title: String
    var isHoliday: Bool
    var style: Style
    var accentColor: Color

    enum Style: Hashable {
        case band
        case compact
    }
}
