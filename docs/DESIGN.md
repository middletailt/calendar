# 設計メモ

## 同期

- 複数 `calendarId`、それぞれ `syncToken`
- Pull: `events.list` + syncToken
- Push: Outbox（`pendingCreate` 等）
- 正: Google、競合時は Google 優先

## 保存形状

| UI | API |
|----|-----|
| 単日 | 単発 insert |
| 複数日（2+） | `RDATE` 付きマスター |
| 繰り返し | `RRULE` |

複数日と繰り返しは排他。`EventDraft.applySelectedDays` / `applyRecurrence` で強制。

## 画面

- `MainCalendarView`: 月グリッド、↩ で前月、⊕ で新規
- `DayEventsSheet`: 選択日の一覧
- `EventEditorView`: カード UI、子画面で複数日・繰り返し・アラーム
