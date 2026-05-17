# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Claudeへの行動指針

- ファイルの新規作成・既存ファイルの変更を問わず、実行前に「何を・どう変えるか・なぜ必要か」をすべて説明してから実行すること。説明を省略しない。

## サービス概要

「ふらりトピック」 — LINEボット。位置情報から最寄駅・近隣カフェを検索し、話題のニュースやYouTube急上昇動画を案内する。データベース不使用（ActiveRecordは未利用）。

## 技術スタック

- Ruby 3.3.11 / Rails 7.1.6
- LINE Messaging API（`line-bot-api` gem）
- HotPepper グルメAPI（Net::HTTP で直接リクエスト）
- HeartRails Express API（最寄駅検索、Net::HTTP）
- YouTube Data API v3（`google-apis-youtube_v3` gem）
- Togetter スクレイピング（Net::HTTP + Nokogiri）

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

**① 複数メッセージが送信されない構文バグ** ✅ 修正済み
- `handle_text_message_controller.rb`（急上昇動画・駅検索）を `[{...}, {...}]` の明示的な配列に修正。
- `handle_location_message_controller.rb`（位置情報）はRubyの `a = x, y` 構文が自動で配列になるため実質問題なし。

**② 最寄駅が1件のときのnilクラッシュ** ✅ 修正済み
- `station_names = stations.map { ... }.uniq.first(2)` で配列化し、`actions` を `station_names.map` で動的生成するよう変更。

**② 最寄駅が0件のときに無応答** ✅ 修正済み
- `handle_location_message_controller.rb` の先頭に `stations.blank?` のガード節を追加し、ユーザーにエラーメッセージを返すよう変更。

**③ Togetterスクレイピングのクラッシュ** ✅ 修正済み
- `mechanize` → Net::HTTP + Nokogiri に切り替え（mechanizeは実質開発終了のため。FerumはJS不要なSSRページには不要と判断）。
- `text.at('h3')` や `text.at('a')` がnilのときは `next unless` でスキップするよう修正。
- `rescue Net::OpenTimeout, Net::ReadTimeout, StandardError` で例外を捕捉し、エラーメッセージを返す。
- `User-Agent` ヘッダーを付与してボット判定を回避。
- レスポンスタイムがFerrum比で約20〜40倍改善（5000〜10000ms → 277ms）。
- ローカルでの動作確認済み。Renderへのデプロイ・本番確認は未実施。

### 優先度2：安定性向上

**④ 外部APIのエラーハンドリング追加** ✅ 修正済み
- `handle_location_message_controller.rb`（HeartRails・HotPepper）
- `Net::HTTP.get_response` → `Net::HTTP.start(open_timeout: 5, read_timeout: 10)` に変更し、タイムアウトを60秒→10秒に短縮。
- `['response']['station']` → `.dig('response', 'station')` に変更し、想定外JSONでもクラッシュしないよう修正。
- `rescue Net::OpenTimeout, Net::ReadTimeout, StandardError` で例外を捕捉し `nil` を返す。呼び出し元の `stations.blank?` がnilを拾ってユーザーにエラーメッセージを返す。

**⑤ HeartRails APIをHTTPS化** ✅ 修正済み
- `handle_location_message_controller.rb` の `http://express.heartrails.com` を `https://` に変更済み。動作確認済み。

### 優先度3：バージョンアップ（中長期）

**⑥ Ruby 3.1.0 → 3.3.11** ✅ 対応済み

**⑦ Rails 7.0 → 7.1.6** ✅ 対応済み

**⑧ mechanize → Net::HTTP + Nokogiri** ✅ 対応済み（改善計画③に統合）

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

### Docker移行（優先度：中）✅ Step 1 完了

- docker-compose構成：`web`（Rails）+ `db`（PostgreSQL）の2サービス
- DBなしの現状でも、将来を見越してPostgreSQL込みの構成で最初から組む
- **移行順序**：
  1. ~~Docker移行（DB接続設定は入れるが機能実装はまだしない）~~ ✅ 完了
  2. ~~Ruby 3.3系 + Rails 7.1へのバージョンアップを同時に実施（改善計画⑥⑦）~~ ✅ 先行して対応済み
  3. RSpec追加（Docker環境でテストが動くよう設定する）
  4. 検索履歴機能を実装
  5. 検索履歴機能のテスト追加

**作成・変更したファイル：**
- `Dockerfile` — `ruby:3.3.11-slim` ベース。bundle install に必要なシステムライブラリを追加
- `docker-compose.yml` — `web`（Rails）+ `db`（PostgreSQL 16-alpine）、`bundle_cache` ボリュームでgemキャッシュ
- `.dockerignore` — `.git`、`log/`、`tmp/`、`storage/`、`.env` を除外
- `config/database.yml` — PostgreSQL + `DATABASE_URL` 環境変数で接続する設定に変更

**`slim` イメージで必要だったシステムライブラリ（ハマりポイント）：**
- `libpq-dev` — `pg` gem（PostgreSQLクライアント）
- `libxml2-dev` / `libxslt1-dev` / `pkg-config` — `nokogiri`（C拡張）
- `libyaml-dev` — `psych 5.3.1`（`dotenv-rails` → `railties` → `irb` → `rdoc` 経由で依存）
- `build-essential` / `nodejs` / `curl` — 基本ビルドツール

**docker compose up --build でのローカル動作確認済み（2026-05-17）**

### RSpec追加（優先度：中、Docker移行後）

- Docker移行後にRSpec環境をセットアップする
- 既存機能（スクレイピング・API呼び出し）のテストから着手
- DB追加後は検索履歴機能のテストも追加

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
