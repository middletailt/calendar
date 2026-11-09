# Calendar（iOS）

個人向けの月表示カレンダー。Google カレンダーを正とした双方向同期（実装予定）に対応する SwiftUI アプリです。

## 要件（確定）

- 月ビューのみ（7 列 × 5〜6 行）
- 日付タップ → 下部シート（予定一覧 + 予定を追加）
- 予定編集: 複数日 ⇔ 繰り返しは厳格に排他
- 複数 Google カレンダー購読、カレンダー別 `syncToken`
- オフライン: A-アウトボックス（スタブあり）

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

## 未実装

- Google OAuth / Calendar API
- 永続化（SwiftData / SQLite）
- ローカル通知
- 検索
