# 設計メモ

Google 連携のセットアップ: [google-calendar-setup.md](google-calendar-setup.md)

## 同期

- 複数 `calendarId`、それぞれ `syncToken`（UserDefaults + SwiftData の `StoredSubscribedCalendar.syncToken`）
- **初回・手動同期**: 今月を中心に **±1 ヶ月（計 3 ヶ月）** の `events.list`（`timeMin` / `timeMax`）。範囲外は削除せずマージ（`applyRangeMerge`）
- **月表示の追撃**: `visibleMonth` が未取得なら同じ **3 ヶ月窓** を取得（`SyncedMonthStore` で月単位管理）
- **増分**: `syncToken` あり・ローカルに同期済みあり → `events.list` + syncToken のみ（トークン無効時は 3 ヶ月窓で再ブート）。マージ後は `trimMemoryToWindowAfterSync` で RAM を窓に戻す
- Push: Outbox → `StoredOutboxItem`（旧 JSON から初回マイグレーション）
- 正: Google、競合時は Google 優先

## メモリ

- `EventStore.events` は **表示月 ±3 ヶ月** のみメモリ保持（`refreshMemoryCache`）。同期マージ直後も `trimMemoryToWindowAfterSync` で窓に戻す。SwiftData には範囲外も残りうる
- 検索・通知は必要時に DB から範囲取得
- 月セルは **4 行まで** 表示（`MonthGridLimits`）

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

## 月パガー

- `MonthCalendarPager`: 前・中・次の 3 枚 + `DragGesture` / `@GestureState`。指離し後は 50% またはフリックで月確定
- 月確定後は親が `MonthGridPageModel` を差し替えてから `committedOffset` を 0 に戻す（`onChange(of: center.month)`）
- ドラッグ状態はパガー内の `@State` に閉じ、スワイプ中は `MonthGridPageView.equatable()` でグリッド再構築を抑える

## 画面

- `MainCalendarView`: 月グリッド（祝日ラベルは「日本の祝日」系カレンダー）、スワイプで月送り、⊕ で新規
- `GoogleSettingsView`: サインイン・手動同期・カレンダー表示 ON/OFF・ローカル通知
- `DayEventsSheet`: 選択日の一覧 → `EventEditorView`（既存予定を開く）
- 既存予定: `EventEditorView`（読み取り専用カレンダーは `isReadOnly`、削除は書き込み可のみ）
- `EventSearchView`: タイトル／場所／メモ検索
- `EventEditorView`: 新規・編集、カード UI、子画面で複数日・繰り返し・アラーム
- Push: insert / patch / delete（Outbox）
