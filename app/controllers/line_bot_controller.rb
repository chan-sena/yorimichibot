class LineBotController < ApplicationController
  require 'mechanize'
  require 'google/apis/youtube_v3'
  require_relative 'handle_text_message_controller'
  require_relative 'handle_location_message_controller'


  # callbackアクションでのみCSRF対策を無効化
  protect_from_forgery except: [:callback]
  def callback
    # StringIOクラスのreadメソッドを用いて文字列としてリクエストのメッセージボディだけを参照し、body変数に代入する
    body = request.body.read
    # 署名の検証(LINE Messaging API SDKに用意されているもの)
    # request.envとすることで署名情報の書かれているヘッダーだけを参照
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    # privateに記載したclientメソッドにアクセス
    # unless文によってtrueが返ってきた場合は中の処理がスキップされfalseが返ってきた場合はunless…endで囲った処理が実行される
    unless client.validate_signature(body, signature)
      # headメソッドはステータスコードを返したい時に使用、失敗の400を返す
      return head :bad_request
    end

    # parse_events_fromメソッドに文字列のメッセージボディを渡すと要素を配列で取得できる
    events = client.parse_events_from(body)
    events.each do |event|
      # case文を用いてeventがLine::Bot::Event::Messageクラスかどうか、ユーザーがメッセージを送信したことを示すイベントかどうかを確認する
      case event
      when Line::Bot::Event::Message
        # eventのtypeキーの値がLine::Bot::Event::MessageType::Text、つまりtextであるかどうか確認
        case event.type
        when Line::Bot::Event::MessageType::Text
          message = HandleTextMessageController.new.handle_text_message(event.message['text'])
          client.reply_message(event['replyToken'], message)
        when Line::Bot::Event::MessageType::Location
          message = HandleLocationMessageController.new.handle_location_message(event.message)
          client.reply_message(event['replyToken'], message)
        end
      end
    end
    # 返信成功のステータスコード200を返す
    head :ok
  end

  private

  # Line::Bot::Clientクラスのインスタンス化
  def client
    # ||=は左辺がnillやfalseの場合、右辺を代入する
    # callbackアクションからclientメソッドを呼び出すことでLINE Messaging API SDKの機能を使うことができる
    @client ||= Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    end
  end
end
