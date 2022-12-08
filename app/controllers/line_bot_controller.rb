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
          if event.message['text'].include?("今日のツイッタートピック")
            message = {
              type: 'text',
              text: tweet_topic.join
            }
          else
            message = {
              type: 'text',
              text: '検索できません'
            }
          end
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

    def tweet_topic
      # 外部APIへGETリクエストするためのライブラリをインスタンス化、このhttp_clientでgetメソッドを使うと指定したURLに対してGETリクエストを行いそのレスポンスを取得できる
      # http_client = HTTPClient.new
      # mechanizeのライブラリをインスタンス化してagent変数に代入
      texts = []
      agent = Mechanize.new
      # agent変数にURLに対してgetリクエストを行い、その結果をpage変数に代入
      page = agent.get("https://togetter.com/ranking")
      page.search('li.has_thumb').first(3).each do |text|
        title = text.at('h3').inner_text
        url = text.at('a.thumb')[:href]
        texts <<
          "☆" + title + "\n"+
          'https://togetter.com/'+ url + "\n"
      end
      texts
      # return results
      # # getメソッドを使用しGETリクエストを送信
      # response = http_client.get(page, elements)
      # # GETリクエストに対するレスポンスをrespon
      # response = JSON.parse(response.body)
      # message = {
      #   type: 'text',
      #   text: elements
      # }
    end
end
