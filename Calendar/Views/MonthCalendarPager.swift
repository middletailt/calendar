import SwiftUI

struct MonthGridPageModel: Equatable {
    var month: YearMonth
    var days: [MonthGridDay]
    var linesByDay: [LocalDay: [MonthCellEventLine]]
    var selectedDay: LocalDay?
    var today: LocalDay
}

/// 月 3 枚パガー。ドラッグ状態はこの View 内に閉じ、親（ヘッダー等）の再描画を抑える。
struct MonthCalendarPager: View {
    let prev: MonthGridPageModel
    let center: MonthGridPageModel
    let next: MonthGridPageModel
    @Binding var visibleMonth: YearMonth

    var onMonthCommitted: (YearMonth) -> Void
    var onSelectDay: (LocalDay) -> Void

    @State private var committedOffset: CGFloat = 0
    @GestureState private var dragTranslation: CGFloat = 0
    @State private var isSettlingPage = false

    /// 指離し後のページ追従（残り距離が短くても急に畳まない）
    private let pageSettleSpring = Animation.spring(response: 0.16, dampingFraction: 0.9, blendDuration: 0.12)
    /// 50% 未満キャンセル用（`withAnimation` が効くよう `.animation(nil)` は committedOffset に付けない）
    private let pageSnapBackAnimation = Animation.easeOut(duration: 0.15)

    private var totalOffset: CGFloat { committedOffset + dragTranslation }

    private func monthPageStack(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            MonthGridPageView(model: prev, onSelectDay: onSelectDay)
                .equatable()
                .frame(width: width, height: height)
            MonthGridPageView(model: center, onSelectDay: onSelectDay)
                .equatable()
                .frame(width: width, height: height)
            MonthGridPageView(model: next, onSelectDay: onSelectDay)
                .equatable()
                .frame(width: width, height: height)
        }
        .frame(width: width * 3, alignment: .leading)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack(alignment: .leading) {
                CalendarTheme.cardBackground
                monthPageStack(width: width, height: height)
                    .offset(x: -width + totalOffset)
            }
            .frame(width: width, height: height, alignment: .leading)
            .clipShape(Rectangle())
            .animation(nil, value: dragTranslation)
            .contentShape(Rectangle())
            .highPriorityGesture(monthDragGesture(pageWidth: width))
        }
        .background(CalendarTheme.cardBackground)
        .onChange(of: visibleMonth) { _, _ in
            isSettlingPage = false
        }
        /// 月確定後のリセンタのみ（スナップバックアニメ中は触らない）
        .onChange(of: center.month) { _, _ in
            guard abs(committedOffset) > 1 else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                committedOffset = 0
            }
        }
    }

    private func monthDragGesture(pageWidth width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .updating($dragTranslation) { value, state, _ in
                if isSettlingPage {
                    flushInFlightPageTurn(pageWidth: width)
                }
                state = value.translation.width
            }
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                let predicted = value.predictedEndTranslation.width

                if abs(vertical) > abs(horizontal), abs(horizontal) < 28 {
                    snapBack(from: horizontal)
                    return
                }

                let halfPage = width * 0.5
                let flickCarry = predicted - horizontal
                let minFlickTravel = min(36, width * 0.09)
                let isFlick = abs(flickCarry) > width * 0.14
                    && abs(horizontal) >= minFlickTravel
                    && abs(predicted) > abs(horizontal)

                if isFlick {
                    if horizontal < 0 {
                        finishSwipe(forward: true, pageWidth: width, releaseOffset: horizontal)
                    } else {
                        finishSwipe(forward: false, pageWidth: width, releaseOffset: horizontal)
                    }
                    return
                }

                if horizontal <= -halfPage {
                    finishSwipe(forward: true, pageWidth: width, releaseOffset: horizontal)
                } else if horizontal >= halfPage {
                    finishSwipe(forward: false, pageWidth: width, releaseOffset: horizontal)
                } else {
                    snapBack(from: horizontal)
                }
            }
    }

    /// スナップ中に次のドラッグが入ったとき、見えている方向へ月を確定する。
    private func flushInFlightPageTurn(pageWidth width: CGFloat) {
        guard isSettlingPage else { return }
        isSettlingPage = false

        let offset = committedOffset
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if offset <= -width * 0.5 {
                let next = visibleMonth.addingMonths(1)
                visibleMonth = next
                onMonthCommitted(next)
            } else if offset >= width * 0.5 {
                let next = visibleMonth.addingMonths(-1)
                visibleMonth = next
                onMonthCommitted(next)
            } else {
                committedOffset = 0
            }
        }
    }

    private func snapBack(from releaseOffset: CGFloat) {
        isSettlingPage = true
        committedOffset = releaseOffset
        withAnimation(pageSnapBackAnimation) {
            committedOffset = 0
        } completion: {
            isSettlingPage = false
        }
    }

    private func finishSwipe(forward: Bool, pageWidth width: CGFloat, releaseOffset: CGFloat) {
        let target = forward ? -width : width
        let nextMonth = visibleMonth.addingMonths(forward ? 1 : -1)
        let clampedRelease = max(-width, min(width, releaseOffset))

        isSettlingPage = true
        committedOffset = clampedRelease
        withAnimation(pageSettleSpring) {
            committedOffset = target
        } completion: {
            isSettlingPage = false
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                visibleMonth = nextMonth
            }
            onMonthCommitted(nextMonth)
        }
    }
}

struct MonthGridPageView: View, Equatable {
    var model: MonthGridPageModel
    var onSelectDay: (LocalDay) -> Void

    static func == (lhs: MonthGridPageView, rhs: MonthGridPageView) -> Bool {
        lhs.model == rhs.model
    }

    var body: some View {
        VStack(spacing: 0) {
            MonthWeekdayHeader()
            monthGrid
        }
        .background(CalendarTheme.cardBackground)
    }

    private var monthGrid: some View {
        let rowCount = max((model.days.count + 6) / 7, 1)

        return GeometryReader { geometry in
            let rowHeight = geometry.size.height / CGFloat(rowCount)

            VStack(spacing: 0) {
                ForEach(0 ..< rowCount, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0 ..< 7, id: \.self) { column in
                            let index = row * 7 + column
                            if index < model.days.count {
                                let cell = model.days[index]
                                let lines = model.linesByDay[cell.day] ?? []
                                MonthDayCell(
                                    day: cell.day,
                                    isInMonth: cell.isInDisplayedMonth,
                                    isToday: cell.day == model.today,
                                    isSelected: model.selectedDay == cell.day,
                                    eventLines: lines,
                                    showsTrailingDivider: column < 6,
                                    showsLeadingDivider: column == 0
                                )
                                .zIndex(model.selectedDay == cell.day ? 2 : 0)
                                .onTapGesture {
                                    onSelectDay(cell.day)
                                }
                            } else {
                                MonthDayCellPlaceholder(
                                    showsTrailingDivider: column < 6,
                                    showsLeadingDivider: column == 0
                                )
                            }
                        }
                    }
                    .frame(height: rowHeight)
                    .overlay(alignment: .bottom) {
                        if row < rowCount - 1 {
                            Rectangle()
                                .fill(CalendarTheme.gridSeparator.opacity(0.6))
                                .frame(height: 0.5)
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
    }
}

private struct MonthWeekdayHeader: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(["日", "月", "火", "水", "木", "金", "土"].enumerated()), id: \.offset) { index, label in
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(weekdayColor(index))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CalendarTheme.gridSeparator.opacity(0.6))
                .frame(height: 0.5)
        }
    }

    private func weekdayColor(_ index: Int) -> Color {
        switch index {
        case 0: CalendarTheme.sunday
        case 6: CalendarTheme.saturday
        default: CalendarTheme.inkSecondary
        }
    }
}
