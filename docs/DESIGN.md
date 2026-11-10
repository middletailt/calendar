# 設計メモ

Google 連携のセットアップ: [google-calendar-setup.md](google-calendar-setup.md)

## 同期

- 複数 `calendarId`、それぞれ `syncToken`（UserDefaults + SwiftData の `StoredSubscribedCalendar.syncToken`）
- **初回・手動同期**: 今月を中心に **±1 ヶ月（計 3 ヶ月）** の `events.list`（`timeMin` / `timeMax`）。範囲外は削除せずマージ（`applyRangeMerge`）
- **月表示の追撃**: `visibleMonth` が未取得なら同じ **3 ヶ月窓** を取得（`SyncedMonthStore` で月単位管理）
- **月グリッド A/B**（設定）: `MonthCalendarPager`（SwiftUI Gesture）と `MonthUIKitScrollPager`（`UIScrollView.isPagingEnabled`）
- **増分**: `syncToken` あり・ローカルに同期済みあり → `events.list` + syncToken のみ（トークン無効時は 3 ヶ月窓で再ブート）
- Push: Outbox → `StoredOutboxItem`（旧 JSON から初回マイグレーション）
- 正: Google、競合時は Google 優先

## ローカル永続化（SwiftData）

| モデル | 内容 |
|--------|------|
| `StoredCalendarEvent` | 予定キャッシュ + `pendingCreate` 等 |
| `StoredSubscribedCalendar` | 購読カレンダー・表示 ON/OFF |
| `StoredOutboxItem` | 未送信の insert/update/delete |

## 保存形状

| UI | API |
|----|-----|
| 単日 | 単発 insert |
| 複数日（2+） | `RDATE` 付きマスター |
| 繰り返し | `RRULE` |

複数日と繰り返しは排他。`EventDraft.applySelectedDays` / `applyRecurrence` で強制。

## 画面

- `MainCalendarView`: 月グリッド（祝日ラベルは「日本の祝日」系カレンダー）、↩ で前月、⊕ で新規
- `DayEventsSheet`: 選択日の一覧 → `EventDetailView`
- `EventDetailView`: 詳細・編集・削除（書き込み可カレンダーのみ）
- `EventSearchView`: タイトル／場所／メモ検索
- `EventEditorView`: 新規・編集、カード UI、子画面で複数日・繰り返し・アラーム
- Push: insert / patch / delete（Outbox）
