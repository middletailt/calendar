import SwiftUI
import UserNotifications

struct GoogleSettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var isWorking = false
    @State private var message: String?
    @AppStorage(MonthPagerStyle.storageKey) private var monthPagerStyleRaw = MonthPagerStyle.swiftUIPager.rawValue

    private var sync: GoogleCalendarSyncService { appState.googleSync }

    var body: some View {
        NavigationStack {
            List {
                Section("月グリッド（A/B）") {
                    Picker("ページング実装", selection: $monthPagerStyleRaw) {
                        ForEach(MonthPagerStyle.allCases) { style in
                            Text(style.label).tag(style.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                    Text("変更はメイン画面に戻ると反映されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("通知（ローカル）") {
                    Text("リモート Push ではなく、端末内の予定リマインダーです。App ID の Push Notifications capability は不要です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("通知を許可する") {
                        Task {
                            _ = await appState.localNotifications.requestAuthorizationIfNeeded()
                            await appState.rebuildNotifications()
                            await appState.localNotifications.refreshAuthorizationStatus()
                        }
                    }
                    if let status = appState.localNotifications.authorizationStatus {
                        Text(authorizationLabel(status))
                            .font(.caption)
                    }
                }

                Section("Google アカウント") {
                    if sync.isSignedIn {
                        Label("接続済み", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Button("サインアウト", role: .destructive) {
                            sync.signOut()
                        }
                    } else {
                        Button("Google でサインイン") {
                            Task { await signIn() }
                        }
                        .disabled(!GoogleOAuthConfig.isConfigured || isWorking)
                    }
                    if !GoogleOAuthConfig.isConfigured {
                        Text("Client ID 未設定。docs/google-calendar-setup.md を参照してください。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if sync.isSignedIn {
                    Section("同期") {
                        Button(sync.isSyncing ? "同期中…" : "今すぐ同期") {
                            Task { await syncNow() }
                        }
                        .disabled(sync.isSyncing || isWorking)
                        if let err = sync.lastError {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }
                    }

                    Section("表示するカレンダー") {
                        ForEach(appState.calendarStore.calendars) { cal in
                            Toggle(isOn: bindingVisibility(cal)) {
                                HStack {
                                    Circle().fill(cal.color).frame(width: 10, height: 10)
                                    Text(cal.title)
                                }
                            }
                            .disabled(!cal.canWrite && cal.accessRoleNote == nil)
                        }
                    }
                }

                if let message {
                    Section {
                        Text(message).font(.caption)
                    }
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func bindingVisibility(_ cal: SubscribedCalendar) -> Binding<Bool> {
        Binding(
            get: {
                appState.calendarStore.calendars.first(where: { $0.id == cal.id })?.isVisible ?? true
            },
            set: { appState.calendarStore.setVisibility(calendarId: cal.id, visible: $0) }
        )
    }

    private func signIn() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await sync.signIn()
            message = "カレンダーを同期しました。"
        } catch {
            message = error.localizedDescription
        }
    }

    private func authorizationLabel(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized: "通知: 許可済み"
        case .denied: "通知: 拒否（iOS 設定から変更）"
        case .notDetermined: "通知: 未確認"
        case .provisional: "通知: 暫定許可"
        case .ephemeral: "通知: 一時許可"
        @unknown default: "通知: 不明"
        }
    }

    private func syncNow() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await sync.syncAllCalendars()
            message = "同期が完了しました。"
        } catch {
            message = error.localizedDescription
        }
    }
}

private extension SubscribedCalendar {
    var accessRoleNote: String? {
        canWrite ? nil : "（読み取り専用）"
    }
}
