import Foundation

/// 月グリッドのページング実装（A/B 比較用）。`UserDefaults` + `@AppStorage` で共有。
enum MonthPagerStyle: String, CaseIterable, Identifiable {
    case swiftUIPager
    case uiScrollView

    var id: String { rawValue }

    var label: String {
        switch self {
        case .swiftUIPager:
            "SwiftUI パガー（Gesture）"
        case .uiScrollView:
            "UIScrollView（isPagingEnabled）"
        }
    }

    static let storageKey = "month_pager_style"
}
