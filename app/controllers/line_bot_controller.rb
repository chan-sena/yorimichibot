class LineBotController < ApplicationController
  require 'mechanize'

  # callbackアクションでのみCSRF対策を無効化
  protect_from_forgery except:[:callback]
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
          transfer_create_message(event.message['text'])
          message = {
            type: 'text',
            # event変数の中身はmessage['text']とすることで取り出せる
            text: event.message['text']
          }
          # Messaging APIで提供されている応答トークン、eventのreplyTokenキーを参照することで取得できる、第一引数に応答トークン、第二引数にmessageを渡すとメッセージの返信が行われる
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
      @client ||= Line::Bot::Client.new { |config|
        config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
        config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
      }
    end

    def transfer_create_message(departure, destination)
      # 外部APIへGETリクエストするためのライブラリをインスタンス化、このhttp_clientでgetメソッドを使うと指定したURLに対してGETリクエストを行いそのレスポンスを取得できる
      http_client = HTTPClient.new
      agent = Mechanize.new
      page = agent.get('https://transit.yahoo.co.jp/search/print?from=#{departure}&flation=&to=#{destination}')
      # page = agent.get('https://transit.yahoo.co.jp/search/result?from=%E6%B1%9F%E5%8F%A4%E7%94%B0&to=%E6%96%B0%E5%AE%BF&fromgid=&togid=&flatlon=&tlatlon=&y=2022&m=11&d=07&hh=17&m1=2&m2=0&type=1&ticket=ic&expkind=1&userpass=1&ws=3&s=0&al=1&shin=1&ex=1&hb=1&lb=1&sr=1')
      elements = page.search('#route03 .station dl dt').inner_text
      puts elements
      response = http_client.get(page, elements)
      response = JSON.parse(response.body)
    end
end
