import SwiftUI

struct RecurrenceSettingsView: View {
    @Bindable var draft: EventDraft
    @State private var frequency: RecurrenceFrequency
    @State private var interval: Int
    @State private var end: RecurrenceEnd

    init(draft: EventDraft) {
        self.draft = draft
        _frequency = State(initialValue: draft.recurrence.frequency)
        _interval = State(initialValue: max(1, draft.recurrence.interval))
        _end = State(initialValue: draft.recurrence.end)
    }

    var body: some View {
        List {
            Section {
                ForEach(RecurrenceFrequency.allCases) { item in
                    Button {
                        frequency = item
                        applyDraft()
                    } label: {
                        HStack {
                            Text(item.title)
                            Spacer()
                            if frequency == item {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }

            Section {
                NavigationLink {
                    RecurrenceEndSettingsView(end: $end, onChange: applyDraft)
                } label: {
                    HStack {
                        Text("繰り返し期限")
                        Spacer()
                        Text(endSummary)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(frequency == .none)

                NavigationLink {
                    RecurrenceIntervalSettingsView(interval: $interval, onChange: applyDraft)
                } label: {
                    HStack {
                        Text("次の間隔で繰り返す")
                        Spacer()
                        Text(interval > 1 ? "\(interval)" : "なし")
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(frequency == .none)
            }
        }
        .navigationTitle("繰り返し")
        .onChange(of: frequency) { _, _ in applyDraft() }
        .onDisappear { applyDraft() }
    }

    private var endSummary: String {
        switch end {
        case .never: "なし"
        case .count(let n): "\(n)回"
        case .until(let day):
            day.formattedLong()
        }
    }

    private func applyDraft() {
        let rule = RecurrenceRule(frequency: frequency, interval: interval, end: end)
        draft.applyRecurrence(rule)
    }
}

struct RecurrenceEndSettingsView: View {
    @Binding var end: RecurrenceEnd
    var onChange: () -> Void
    @State private var mode: Int = 0
    @State private var count: Int = 10
    @State private var until: Date = Date()

    var body: some View {
        Form {
            Picker("終了", selection: $mode) {
                Text("なし").tag(0)
                Text("回数").tag(1)
                Text("日付まで").tag(2)
            }
            .pickerStyle(.inline)
            .onChange(of: mode) { _, _ in commit() }

            if mode == 1 {
                Stepper("\(count) 回", value: $count, in: 1 ... 999)
                    .onChange(of: count) { _, _ in commit() }
            }
            if mode == 2 {
                DatePicker("期限", selection: $until, displayedComponents: .date)
                    .onChange(of: until) { _, _ in commit() }
            }
        }
        .navigationTitle("繰り返し期限")
        .onAppear { load() }
    }

    private func load() {
        switch end {
        case .never: mode = 0
        case .count(let n): mode = 1; count = n
        case .until(let day):
            mode = 2
            until = day.date() ?? Date()
        }
    }

    private func commit() {
        switch mode {
        case 0: end = .never
        case 1: end = .count(count)
        default: end = .until(LocalDay(until))
        }
        onChange()
    }
}

struct RecurrenceIntervalSettingsView: View {
    @Binding var interval: Int
    var onChange: () -> Void

    var body: some View {
        Form {
            Stepper(value: $interval, in: 1 ... 30) {
                Text("間隔: \(interval)")
            }
            .onChange(of: interval) { _, _ in onChange() }
        }
        .navigationTitle("繰り返し間隔")
    }
}
