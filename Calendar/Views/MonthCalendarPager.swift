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
    @State private var commitTask: Task<Void, Never>?

    private let settleAnimation = Animation.easeOut(duration: 0.2)

    private var totalOffset: CGFloat { committedOffset + dragTranslation }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

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
            .offset(x: -width + totalOffset)
            .drawingGroup(opaque: false)
            .animation(nil, value: dragTranslation)
            .contentShape(Rectangle())
            .highPriorityGesture(monthDragGesture(pageWidth: width))
        }
        .clipped()
        .onChange(of: visibleMonth) { _, _ in
            committedOffset = 0
            commitTask?.cancel()
        }
    }

    private func monthDragGesture(pageWidth width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .updating($dragTranslation) { value, state, _ in
                commitTask?.cancel()
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

                let threshold = min(44, width * 0.11)
                let fling = abs(predicted - horizontal) > width * 0.15
                let shouldNext = horizontal < -threshold || (horizontal < 0 && fling && predicted < -threshold)
                let shouldPrev = horizontal > threshold || (horizontal > 0 && fling && predicted > threshold)

                if shouldNext {
                    finishSwipe(forward: true, pageWidth: width, releaseOffset: horizontal)
                } else if shouldPrev {
                    finishSwipe(forward: false, pageWidth: width, releaseOffset: horizontal)
                } else {
                    snapBack(from: horizontal)
                }
            }
    }

    private func snapBack(from releaseOffset: CGFloat) {
        committedOffset = releaseOffset
        withAnimation(settleAnimation) {
            committedOffset = 0
        }
    }

    private func finishSwipe(forward: Bool, pageWidth width: CGFloat, releaseOffset: CGFloat) {
        let target = forward ? -width : width
        let remaining = abs(target - releaseOffset)
        let duration = 0.2 * min(1, remaining / width)
        let settle = max(0.07, duration)
        let nextMonth = visibleMonth.addingMonths(forward ? 1 : -1)

        committedOffset = releaseOffset
        withAnimation(.easeOut(duration: settle)) {
            committedOffset = target
        }

        commitTask?.cancel()
        commitTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(settle))
            guard !Task.isCancelled else { return }
            visibleMonth = nextMonth
            committedOffset = 0
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
