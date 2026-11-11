import SwiftUI

struct ReminderSettingsView: View {
    @Binding var reminderMinutes: [Int]

    var body: some View {
        List {
            Section {
                ForEach(EventReminderPresets.options, id: \.minutes) { option in
                    let selected = reminderMinutes.contains(option.minutes)
                    let selectionFull = reminderMinutes.count >= EventReminderPresets.maximumSelectionCount
                    let disabled = selectionFull && !selected

                    Button {
                        toggle(option.minutes)
                    } label: {
                        HStack {
                            Text(option.label)
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                    .disabled(disabled)
                    .opacity(disabled ? 0.45 : 1)
                }
            } footer: {
                Text("最大\(EventReminderPresets.maximumSelectionCount)つまで選べます。")
            }
        }
        .navigationTitle("通知アラーム")
    }

    private func toggle(_ minutes: Int) {
        if reminderMinutes.contains(minutes) {
            reminderMinutes.removeAll { $0 == minutes }
        } else if reminderMinutes.count < EventReminderPresets.maximumSelectionCount {
            reminderMinutes.append(minutes)
        }
    }
}
