# Calendar（iOS）

個人向けの月表示カレンダー。Google カレンダーを正とした双方向同期に対応する SwiftUI アプリです。

## 要件（確定）

- 動作環境: **iOS 18 以降**
- 月ビューのみ（7 列 × 5〜6 行）。月送りは **`MonthCalendarPager`**（SwiftUI + `DragGesture`）
- 日付タップ → 下部シート（予定一覧 + 予定を追加）
- 予定編集: 複数日 ⇔ 繰り返しは厳格に排他
- 複数 Google カレンダー購読、カレンダー別 `syncToken`
- オフライン: A-アウトボックス（SwiftData の `StoredOutboxItem`）
- ローカル永続化: SwiftData（予定・購読カレンダー・Outbox）
- ローカル通知（予定リマインダー）、予定検索

## 開発

1. `Calendar.xcodeproj` を Xcode 16.2+ で開く
2. Signing & Capabilities で Team を設定
3. シミュレータまたは実機で Run

```bash
xcodebuild -project Calendar.xcodeproj -scheme Calendar \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## 構成

| パス | 内容 |
|------|------|
| `Calendar/Views` | メイン画面・月パガー・日シート・予定編集・設定 |
| `Calendar/Models` | `EventDraft`, `RecurrenceRule`, 同期状態 |
| `Calendar/Services` | `EventStore`, `GoogleCalendarSyncService`, 通知 |

詳細は [docs/DESIGN.md](docs/DESIGN.md)。

## Google Calendar

セットアップ手順: [docs/google-calendar-setup.md](docs/google-calendar-setup.md)

- OAuth（`ASWebAuthenticationSession`）+ トークン Keychain
- `calendarList` / `events.list`（期間取得 + `syncToken` 差分）
- 予定の作成・更新・削除 → Outbox → `events.insert` / `patch` / `delete`

## 今後の検討

- 増分同期で蓄積した SwiftData の期間外データの整理
- 月スワイプ終端でのラベル位置の微調整
