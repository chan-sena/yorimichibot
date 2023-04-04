# ふらりトピック

## リリースノート(最終更新 2023.03.17)

- デモ動画追加(2023.04.04)

## ふらりトピックデモ動画(カフェ検索)

![20230403_225143](https://user-images.githubusercontent.com/77098696/229530419-c2d4b3f2-d1b1-402b-844a-750891ec1b3c.gif)

## ふらりトピックデモ動画(ニュース、動画検索など)

![20230404_214726](https://user-images.githubusercontent.com/77098696/229796845-d513f7e9-8de2-4574-bffe-0a4576cfffaf.gif)

- 環境構築(2022.10.18)
  <br>
  Django で環境構築をしてみたが同じ機能を rails でも作成できそうであったため rails での環境構築を再度開始

- 画面遷移図作成(2022.10.12)
  https://www.figma.com/file/sWO6Vg03seP5p7huN6RAzM/%E3%82%88%E3%82%8A%E3%81%BF%E3%81%A1bot-%E7%94%BB%E9%9D%A2%E9%81%B7%E7%A7%BB%E5%9B%B3?node-id=0%3A1

## サービス概要

ふらっと寄り道したい時やひまつぶししたい時にタップひとつで近隣のお店を検索できたり、ひまつぶしできるニュースや動画を紹介する自動 bot サービスです

## メインのターゲットユーザー

20 代の男女、独身、ひとりぐらし
日々仕事や学校に追われているがたまに息抜きがしたい人

## ユーザーが抱える課題

ひまつぶししたり近隣の寄り道できる場所を探すにも毎度ブラウザを立ち上げていくつものサイトを検索しないといけず、とにかくめんどくさい

## 解決方法

LINEbot という形式で直感的に現在地の最寄駅を割り出し、その近隣のカフェやレストランを表示することで寄り道が楽しめるようにする
同時にニュースサイトや動画などそこに行って楽しめるもの、ひまつぶしできるものをタップ 1 つで案内できるようにした

## 実装機能

- 最寄駅検索機能

  - heartrails の API を使い位置情報の緯度経度から最寄駅までの距離を検索

- カフェ検索
  - 最寄駅検索でわかった最寄駅からホットペッパー API を使用し、近隣のカフェを検索する

* ニュース検索

  - 今話題になっているニュースとして Togetter まとめの急上昇ランキングを mechanize を利用してスクレイピングし、ワンタップで表示

* 急上昇動画検索

  - Youtube の急上昇動画の項目を YoutubeAPI を利用し取得しワンタップで表示

* お問合せ
  - バグ報告などの問い合わせ窓口を Google フォームで作成

## なぜこのサービスを作りたいか

めんどくさがりやだけどどこかに行きたい、あまり時間がないけど息抜きしたいがいちいちインターネットで場所を検索することが億劫でありできるだけ効率的で簡単に寄り道できるサイトがあったらいいなと思ったから。

## スケジュール

企画,技術調査,README,画面遷移図,ER 図作成：10/14 〆切
メイン機能実装：3 月上旬まで
β 版リリース(MVP)：3/22
本番リリース：3 月末
