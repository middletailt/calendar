# Google Calendar 連携セットアップ

## 1. Google Cloud Console

1. [Google Cloud Console](https://console.cloud.google.com/) でプロジェクトを作成
2. **API とサービス → ライブラリ** で **Google Calendar API** を有効化
3. **OAuth 同意画面** を設定（ユーザータイプ: 外部 → テストユーザーに自分の Google アカウントを追加）
4. **認証情報 → 認可情報を作成 → OAuth クライアント ID**
   - アプリケーションの種類: **iOS**
   - バンドル ID: `com.middletail.calendar`（Xcode と同じこと）

作成後、**クライアント ID**（`….apps.googleusercontent.com`）を控える。

## 2. アプリ側の設定

### 方法 A: `GoogleOAuth.plist`（推奨・gitignore 済み）

```bash
cp Calendar/Resources/GoogleOAuth.plist.example Calendar/Resources/GoogleOAuth.plist
```

`CLIENT_ID` にクライアント ID を記入し、Xcode で **Calendar** ターゲットにファイルを追加（Copy Bundle Resources）。

### 方法 B: Info.plist

`GoogleClientID` キーに同じクライアント ID を設定。

### URL スキーム（必須）

クライアント ID が `1234567890-abc.apps.googleusercontent.com` のとき、URL スキームは:

`com.googleusercontent.apps.1234567890-abc`

Xcode → **Calendar** ターゲット → **Info** → **URL Types** に上記スキームを 1 件追加（`Info.plist` の `CFBundleURLTypes` と同じ）。

`Info.plist` にプレースホルダを入れている場合は、実 ID に合わせて **スキームも手で合わせる**こと。

## 3. 動作確認

1. アプリ起動 → **設定**（歯車）→ **Google でサインイン**
2. ブラウザで許可 → カレンダー一覧が表示され、同期で予定が読み込まれる
3. 予定追加 → Google カレンダーに反映（オンライン時）

## 4. 通知（ローカル）

予定のリマインダーは **ローカル通知** です。Apple Developer の App ID で **Push Notifications** capability を有効にする必要はありません。初回起動または設定の「通知を許可する」で iOS の許可ダイアログが出ます。

## 5. トラブルシュート

| 症状 | 対処 |
|------|------|
| Client ID 未設定 | `GoogleOAuth.plist` または `GoogleClientID` |
| redirect_uri_mismatch | URL スキームと OAuth iOS クライアントのバンドル ID を確認 |
| 403 access_denied | テストユーザーに自分を追加 |
| 同期トークンエラー | 設定から「今すぐ同期」（フル同期にフォールバック） |
