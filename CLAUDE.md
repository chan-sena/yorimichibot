# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## サービス概要

「ふらりトピック」 — LINEボット。位置情報から最寄駅・近隣カフェを検索し、話題のニュースやYouTube急上昇動画を案内する。データベース不使用（ActiveRecordは未利用）。

## 技術スタック

- Ruby 3.1.0 / Rails 7.0.0
- LINE Messaging API（`line-bot-api` gem）
- HotPepper グルメAPI（Net::HTTP で直接リクエスト）
- HeartRails Express API（最寄駅検索、Net::HTTP）
- YouTube Data API v3（`google-apis-youtube_v3` gem）
- Togetter スクレイピング（`mechanize` gem）

## よく使うコマンド

```bash
bundle install
rails s
bundle exec rubocop
```

テストは未整備（test/ ディレクトリは空）。

## アーキテクチャ

LINEからのWebhookは `POST /callback` → `LineBotController#callback` で受信。メッセージ種別に応じて2つのコントローラーに処理を委譲する構造。

```
LineBotController          # 署名検証・イベントルーティング
├── HandleTextMessageController   # テキストメッセージ処理
│   ├── tweet_topic        # Togetterスクレイピング
│   └── youtube_topic      # YouTube API
└── HandleLocationMessageController  # 位置情報メッセージ処理
    ├── stations           # HeartRails API（最寄駅）
    ├── search_restaurants # HotPepper API
    └── restaurants_bubble # Flex Messageビルダー
```

`HandleTextMessageController` と `HandleLocationMessageController` は `LineBotController` を継承しているが、実態はServiceクラス相当（HTTP対応のコントローラーではない）。

## 改善計画

### 優先度1：今すぐ直せるバグ

**① 複数メッセージが送信されない構文バグ**
- `handle_text_message_controller.rb:12-20`（急上昇動画）、`41-49`（駅検索）
- `handle_location_message_controller.rb:16-35`（位置情報）
- カンマ区切りハッシュになっており2つ目のメッセージが届いていない。`[{...}, {...}]` の配列に修正する。

**② 最寄駅が1件のときのnilクラッシュ** ✅ 修正済み
- `station_names = stations.map { ... }.uniq.first(2)` で配列化し、`actions` を `station_names.map` で動的生成するよう変更。

**③ Togetterスクレイピングのクラッシュ**
- `handle_text_message_controller.rb:66-80`
- `text.at('h3')` や `text.at('a')` がnilを返したときにクラッシュ。エラーハンドリング追加またはRSSへの切り替えを検討。

### 優先度2：安定性向上

**④ 外部APIのエラーハンドリング追加**
- `handle_location_message_controller.rb:46-47`（HeartRails）、`62-63`（HotPepper）
- APIエラー・タイムアウト時に begin/rescue でユーザーへエラーメッセージを返す。

**⑤ HeartRails APIをHTTPS化**
- `handle_location_message_controller.rb:40`
- `http://` → `https://` に変更するだけ。位置情報を非暗号化通信で送っている。

### 優先度3：バージョンアップ（中長期）

**⑥ Ruby 3.1.0 → 3.3系**（2024年12月EOL済み）

**⑦ Rails 6.1 → 7.1**（2023年EOL済み。6.1→7.0→7.1と段階的に更新）

**⑧ mechanize → RSS or Ferrum**
- まずTogetterにランキングRSSがあるか確認。あればRSSで代替が最小コスト。なければFerumを検討。

## デプロイ・運用

- **デプロイ先**: Render（無料プラン）
- **Renderの無料プランについて**: 2026年4月時点でも無料プランは存在する（完全廃止ではない）。Dashboardでプラン表示が「Free」であることを確認済み。
  - 15分間アクセスがないとスリープする仕様は継続中（「Your free instance will spin down with inactivity, which can delay requests by 50 seconds or more.」という警告がDashboardに表示されている）
- **スリープ対策**: UptimeRobotで5分ごとに `GET /hello/index` へリクエストを送りスリープを防止
  - `routes.rb` の `get 'hello/index'` はUptimeRobot用のエンドポイント
- **LINEのWebhook URL**: `https://hurari-topic.onrender.com/callback`
- **開発当時の記録**: 2023年に開発者本人が書いたQiita記事あり → https://qiita.com/chanse_____/items/facc99c791d9705ebeba（UptimeRobotでのスリープ対策について）

## トリガーワード一覧

| ユーザーが送るテキスト | 動作 |
|----------------------|------|
| `今日のトピック` | Togetterランキングをスクレイピングして表示 |
| `急上昇動画` | YouTube急上昇動画（日本、10件）をFlex Messageで表示 |
| `現在地検索` | 位置情報送信ボタンを表示 |
| `〇〇駅`（「駅」を含む文字列） | HotPepperで駅周辺のカフェを検索 |
| 位置情報メッセージ | HeartRailsで最寄駅を取得し駅ボタンを表示 |
| その他 | 自動応答BOTの旨を返信 |

## 今後の開発計画

### Docker移行（優先度：中）

- docker-compose構成：`web`（Rails）+ `db`（PostgreSQL）の2サービス
- DBなしの現状でも、将来を見越してPostgreSQL込みの構成で最初から組む
- **移行順序**：
  1. Docker移行（DB接続設定は入れるが機能実装はまだしない）
  2. Ruby 3.3系 + Rails 7.1へのバージョンアップを同時に実施（改善計画⑥⑦）
  3. 検索履歴機能を実装

### 検索履歴機能（優先度：低、Docker移行後）

- 検索履歴を1ヶ月分保持し、リクエストに応じて返す
- ActiveRecord（PostgreSQL）で構築予定
- **DB候補**：Supabase無料枠（500MBまで無料）
  - RenderのフリーPostgreSQLは90日で失効するため不採用
  - RailwayはDB候補（$5クレジット/月）

## 環境変数

`.env` に記載（`.gitignore` で除外済み）。`.env.example` を参照。

```
LINE_CHANNEL_SECRET
LINE_CHANNEL_TOKEN
YOUTUBE_API_KEY
HOTPEPPER_API
```
