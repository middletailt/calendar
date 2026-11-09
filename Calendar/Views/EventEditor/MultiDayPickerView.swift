import SwiftUI

struct MultiDayPickerView: View {
    @Bindable var draft: EventDraft
    @Environment(\.dismiss) private var dismiss
    @State private var visibleMonth: YearMonth
    @State private var workingSelection: Set<LocalDay>

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    init(draft: EventDraft) {
        self.draft = draft
        let startDay = LocalDay(draft.start)
        _visibleMonth = State(initialValue: YearMonth(year: startDay.year, month: startDay.month))
        _workingSelection = State(initialValue: draft.selectedDays)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .padding(10)
                        .background(Color.white, in: Circle())
                }
                Spacer()
                Button(confirm) {
                    draft.applySelectedDays(workingSelection)
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.blue, in: Circle())
                }
            }
            .padding(.horizontal)

            Text("追加したい日付を選択してください。")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            monthHeader

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(MonthGridBuilder.days(for: visibleMonth)) { cell in
                    MultiSelectDayCell(
                        day: cell.day,
                        isInMonth: cell.isInDisplayedMonth,
                        isSelected: workingSelection.contains(cell.day)
                    )
                    .onTapGesture {
                        toggle(cell.day)
                    }
                }
            }
            .padding(.horizontal, 8)
            .background(Color.white)

            if workingSelection.count > 1 {
                Text("複数日を選択すると繰り返しはリセットされます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.top, 8)
        .background(Color(red: 0.93, green: 0.93, blue: 0.96))
        .navigationBarHidden(true)
    }

    private var monthHeader: some View {
        HStack {
            Button {
                visibleMonth = visibleMonth.addingMonths(-1)
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthTitle)
                .font(.headline)
            Spacer()
            Button {
                visibleMonth = visibleMonth.addingMonths(1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal, 24)
    }

    private var monthTitle: String {
        var comps = DateComponents()
        comps.year = visibleMonth.year
        comps.month = visibleMonth.month
        comps.day = 1
        guard let date = Calendar.current.date(from: comps) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年 M月"
        return f.string(from: date)
    }

    private func toggle(_ day: LocalDay) {
        if workingSelection.contains(day) {
            if workingSelection.count > 1 {
                workingSelection.remove(day)
            }
        } else {
            workingSelection.insert(day)
        }
    }

    private func confirm() {
        if workingSelection.isEmpty {
            workingSelection = [LocalDay(draft.start)]
        }
    }
}

struct MultiSelectDayCell: View {
    var day: LocalDay
    var isInMonth: Bool
    var isSelected: Bool

    var body: some View {
        Text("\(day.day)")
            .font(.body)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(isInMonth ? .primary : .secondary.opacity(0.5))
            .background(isSelected ? Color.blue.opacity(0.2) : Color.white)
            .overlay(Rectangle().stroke(Color(white: 0.9), lineWidth: 0.5))
    }
}
