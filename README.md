# Calendar（iOS）

個人向けの月表示カレンダー。Google カレンダーを正とした双方向同期（実装予定）に対応する SwiftUI アプリです。

## 要件（確定）

- 動作環境: **iOS 18 以降**
- 月ビューのみ（7 列 × 5〜6 行）
- 日付タップ → 下部シート（予定一覧 + 予定を追加）
- 予定編集: 複数日 ⇔ 繰り返しは厳格に排他
- 複数 Google カレンダー購読、カレンダー別 `syncToken`
- オフライン: A-アウトボックス（SwiftData の `StoredOutboxItem`）
- ローカル永続化: SwiftData（予定・購読カレンダー・Outbox）

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
| `Calendar/Views` | メイン画面・日シート・予定編集 |
| `Calendar/Models` | `EventDraft`, `RecurrenceRule`, 同期状態 |
| `Calendar/Services` | `EventStore`, `GoogleCalendarSyncing`（スタブ） |

詳細は [docs/DESIGN.md](docs/DESIGN.md)。

## Google Calendar

セットアップ手順: [docs/google-calendar-setup.md](docs/google-calendar-setup.md)

- OAuth（`ASWebAuthenticationSession`）+ トークン Keychain
- `calendarList` / `events.list`（syncToken 差分）
- 予定作成 → Outbox → `events.insert`

## 未実装

- 予定の更新・削除、編集画面からの同期
- 永続化（イベントキャッシュの再起動後復元）
- ローカル通知
- 検索
