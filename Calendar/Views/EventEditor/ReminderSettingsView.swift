import SwiftUI

struct ReminderSettingsView: View {
    @Binding var reminderMinutes: [Int]

    private let presets = [0, 10, 30, 60, 24 * 60]

    var body: some View {
        List {
            Section {
                ForEach(presets, id: \.self) { minutes in
                    Button {
                        toggle(minutes)
                    } label: {
                        HStack {
                            Text(label(for: minutes))
                            Spacer()
                            if reminderMinutes.contains(minutes) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle("通知アラーム")
    }

    private func label(for minutes: Int) -> String {
        switch minutes {
        case 0: "開始時"
        case 24 * 60: "1日前"
        default:
            minutes >= 60 ? "\(minutes / 60)時間前" : "\(minutes)分前"
        }
    }

    private func toggle(_ minutes: Int) {
        if reminderMinutes.contains(minutes) {
            reminderMinutes.removeAll { $0 == minutes }
        } else {
            reminderMinutes.append(minutes)
        }
    }
}
