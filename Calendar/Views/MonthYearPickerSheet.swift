import SwiftUI

struct MonthYearPickerSheet: View {
    var onCommit: (YearMonth) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var year: Int
    @State private var month: Int

    private let yearRange = 2020 ... 2035

    init(current: YearMonth, onCommit: @escaping (YearMonth) -> Void) {
        self.onCommit = onCommit
        _year = State(initialValue: current.year)
        _month = State(initialValue: current.month)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Picker("年", selection: $year) {
                    ForEach(Array(yearRange), id: \.self) { y in
                        Text(verbatim: "\(y)年").tag(y)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Picker("月", selection: $month) {
                    ForEach(1 ... 12, id: \.self) { m in
                        Text(verbatim: "\(m)月").tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .labelsHidden()

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .frame(width: 52, height: 52)
                        .background(CalendarTheme.elevatedControl, in: Circle())
                }

                Spacer()

                Button {
                    apply()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(CalendarTheme.fabForeground)
                        .frame(width: 52, height: 52)
                        .background(CalendarTheme.accent, in: Circle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .padding(.top, 8)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }

    private func apply() {
        onCommit(YearMonth(year: year, month: month))
        dismiss()
    }
}
