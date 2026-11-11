import Foundation

enum MonthGridLimits {
    /// 月セルに描画する予定行の上限（帯・コンパクト合計）
    static let maxEventLinesPerDay = 4
    /// `EventStore.events` に保持する月半径（表示 ± 隣接 + 余裕）
    static let memoryWindowRadiusMonths = 3
}
