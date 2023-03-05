class LineBotController < ApplicationController
  require 'mechanize'
  require 'google/apis/youtube_v3'


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
          if event.message['text'].include?('今日のトピック')
            message = {
              type: 'text',
              text: '☆今話題になっているトピック☆' + "\n" + "\n" + tweet_topic.join
            }
          elsif event.message['text'].include?('急上昇動画')
            message = {
              type: 'flex',
              altText: 'Youtubeの検索結果です。',
              contents: youtube_topic
            }
          elsif event.message['text'].include?('現在地検索')
            message = {
              type: 'template',
              altText: '現在地検索中',
              template: {
                type: 'buttons',
                title: '最寄駅を検索🔍',
                text: '現在地から一番近い最寄駅と最寄駅近くのカフェスポットを検索します',
                actions: [
                  {
                    type: 'uri',
                    label: '現在地を送信',
                    uri: 'https://line.me/R/nv/location/'
                  }
                ]
              }
            }
          elsif event.message['text'].include?('駅')
            text = event.message['text']
            results = search_restaurants(text)
            if results.present?
              message = {
                type: 'flex',
                altText: 'よりみちできるカフェスポットの検索結果です！',
                contents: restaurants_bubble(results)
              }
              # reply_text = results.map{|result| "☆#{result['name']}"+ "\n" + "ジャンル：#{result['genre']['name']}" + "\n" + "住所：#{result['address']}"+ "\n" + "営業日時：#{result['open']}"+ "\n" + "休日：#{result['close']}"+ "\n" + "URL：#{result['urls']['pc']}"}.join("\n")
            else
              reply_text = "「#{text}」に該当するお店は見つかりませんでした。"
              message = {
                type: 'text',
                text: reply_text
              }
            end
            # message ={
            #   type: 'text',
            #   text: 'よりみちできるグルメスポットの検索結果です！' + "\n" + "\n" +  reply_text + "\n" + "\n" + 'Powered by ホットペッパー Webサービス'
            # }
          else
            message = {
              type: 'text',
              text: 'こちらは自動応答BOTになるため個別での応答をすることはできません。当BOTに関するバグ報告やご要望などは【お問い合わせ】よりご連絡くださいませ。'
            }
          end
          client.reply_message(event['replyToken'], message)
        when Line::Bot::Event::MessageType::Location
          # p event['message']['latitude']
          # p event['message']['longitude']
          # p stations(event['message']['longitude'], event['message']['latitude'])
          stations = stations(event['message']['longitude'], event['message']['latitude'])
          station_message = stations.map do |station|
            "🚃#{station['name']}駅   #{station['line']}(#{station['distance']})"
          end.join("\n")
          client.reply_message(event['replyToken'],
                               { type: 'text',
                                 text: '【最寄駅と最寄路線までの距離です】' + "\n" + station_message + "\n" + "\n" + '最寄駅周辺のよりみちできるカフェスポットを調べる場合はメッセージ送信欄に【' + stations.map do |station|
                                                                                                                                                "#{station['name']}"
                                                                                                                                              end.first + '駅】のように調べたい駅名を入力してください。※駅まで含めて入力ください。' })
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

  def tweet_topic
    # 外部APIへGETリクエストするためのライブラリをインスタンス化、このhttp_clientでgetメソッドを使うと指定したURLに対してGETリクエストを行いそのレスポンスを取得できる
    # http_client = HTTPClient.new
    # mechanizeのライブラリをインスタンス化してagent変数に代入
    tweet_texts = []
    agent = Mechanize.new
    # agent変数にURLに対してgetリクエストを行い、その結果をpage変数に代入
    page = agent.get('https://togetter.com/ranking')
    page.search('li div.inner').first(10).each_with_index do |text, index|
      title = text.at('h3').inner_text
      url = text.at('a')[:href]
      tweet_texts <<
        "【#{index + 1}】" + title + "\n" +
        'https://togetter.com/' + url + "\n" + "\n"
    end
    tweet_texts
  end

  def youtube_topic
    youtube = Google::Apis::YoutubeV3::YouTubeService.new
    youtube.key = ENV['YOUTUBE_API_KEY']
    response = youtube.list_videos('snippet', chart: 'mostPopular', max_results: 10, region_code: 'jp')
    youtube_texts = []
    response.items.each do |item|
      @image = item.snippet.thumbnails.default.url
      @url = item.id
      @title = item.snippet.title
      @description = item.snippet.description
      @channel_title = item.snippet.channel_title
      youtube_texts.push youtube_topic_bubble
      # youtube_texts <<
      # youtube_texts
      #  "☆"+ @title + "\n" + "\n" + "https://www.youtube.com/watch?v=" + @url + "\n" + "\n"
    end
    {
      type: 'carousel',
      contents: youtube_texts
    }
  end

  def youtube_topic_bubble
    {
      type: 'bubble',
      hero: {
        type: 'image',
        url: @image,
        size: 'full',
        aspectRatio: '20:13',
        aspectMode: 'cover',
        action: {
          type: 'uri',
          uri: 'https://www.youtube.com/watch?v=' + @url
        }
      },
      body: {
        type: 'box',
        layout: 'vertical',
        contents: [
          {
            type: 'text',
            text: @title,
            weight: 'bold',
            size: 'md',
            wrap: true,
            action: {
              type: 'uri',
              label: 'action',
              uri: 'https://www.youtube.com/watch?v=' + @url
            }
          },
          {
            type: 'box',
            layout: 'vertical',
            margin: 'lg',
            spacing: 'sm',
            contents: [
              {
                type: 'box',
                layout: 'baseline',
                contents: [
                  {
                    type: 'text',
                    text: @description,
                    color: '#aaaaaa',
                    size: 'sm'
                  }
                ]
              },
              {
                type: 'box',
                layout: 'baseline',
                spacing: 'sm',
                contents: [
                  {
                    type: 'text',
                    text: 'チャンネル',
                    color: '#aaaaaa',
                    size: 'sm',
                    flex: 2,
                    wrap: true
                  },
                  {
                    type: 'text',
                    text: @channel_title,
                    wrap: true,
                    color: '#666666',
                    size: 'sm',
                    flex: 5
                  }
                ]
              }
            ]
          }
        ]
      },
      footer: {
        type: 'box',
        layout: 'vertical',
        contents: []
      }
    }
  end

  def stations(longitude, latitude)
    uri = URI('http://express.heartrails.com/api/json')
    uri.query = URI.encode_www_form({
                                      method: 'getStations',
                                      x: longitude,
                                      y: latitude
                                    })
    res = Net::HTTP.get_response(uri)
    JSON.parse(res.body)['response']['station']
  end

  def search_restaurants(keyword)
    keyword_without_station = keyword.gsub('駅', '')
    uri = URI('http://webservice.recruit.co.jp/hotpepper/gourmet/v1/')
    uri.query = URI.encode_www_form({
                                      key: ENV['HOTPEPPER_API'],
                                      keyword: keyword_without_station,
                                      genre: 'G014',
                                      range: 2,
                                      count: 12,
                                      order: 4,
                                      format: 'json'
                                    })
    res = Net::HTTP.get_response(uri)
    JSON.parse(res.body)['results']['shop']
  end

  def restaurants_bubble(shops)
    bubbles = []
    shops.map do |shop|
      bubble =
        {
          type: 'bubble',
          hero: {
            type: 'image',
            url: shop['photo']['mobile']['l'],
            size: 'full',
            aspectRatio: '20:13',
            aspectMode: 'cover',
            action: {
              type: 'uri',
              uri: shop['urls']['pc']
            }
          },
          body: {
            type: 'box',
            layout: 'vertical',
            contents: [
              {
                type: 'text',
                text: shop['name'],
                weight: 'bold',
                size: 'xl',
                wrap: true
              },
              {
                type: 'box',
                layout: 'vertical',
                margin: 'lg',
                spacing: 'sm',
                contents: [
                  {
                    type: 'box',
                    layout: 'baseline',
                    contents: [
                      {
                        type: 'text',
                        text: 'カテゴリ',
                        flex: 1,
                        size: 'sm',
                        color: '#aaaaaa',
                        wrap: true
                      },
                      {
                        type: 'text',
                        text: shop['genre']['name'],
                        flex: 3,
                        size: 'sm',
                        color: '#666666'
                      }
                    ]
                  },
                  {
                    type: 'box',
                    layout: 'baseline',
                    spacing: 'sm',
                    contents: [
                      {
                        type: 'text',
                        text: '住所',
                        color: '#aaaaaa',
                        size: 'sm',
                        flex: 1
                      },
                      {
                        type: 'text',
                        wrap: true,
                        color: '#666666',
                        size: 'sm',
                        flex: 5,
                        text: shop['address']
                      }
                    ]
                  },
                  {
                    type: 'box',
                    layout: 'baseline',
                    spacing: 'sm',
                    contents: [
                      {
                        type: 'text',
                        text: '営業日時',
                        color: '#aaaaaa',
                        size: 'sm',
                        flex: 1
                      },
                      {
                        type: 'text',
                        color: '#666666',
                        size: 'sm',
                        flex: 3,
                        text: shop['open']
                      }
                    ]
                  },
                  {
                    type: 'box',
                    layout: 'baseline',
                    contents: [
                      {
                        type: 'text',
                        text: '休日',
                        flex: 1,
                        color: '#aaaaaa',
                        size: 'sm'
                      },
                      {
                        type: 'text',
                        text: shop['close'],
                        flex: 3,
                        size: 'sm',
                        color: '#666666'
                      }
                    ]
                  },
                  {
                    type: 'box',
                    layout: 'baseline',
                    contents: [
                      {
                        type: 'text',
                        action: {
                          type: 'uri',
                          label: 'action',
                          uri: 'http://webservice.recruit.co.jp/'
                        },
                        text: 'Powered by ホットペッパー Webサービス',
                        wrap: true,
                        size: 'xs',
                        color: '#aaaaaa'
                      }
                    ]
                  }
                ]
              }
            ]
          },
          footer: {
            type: 'box',
            layout: 'vertical',
            spacing: 'sm',
            contents: [
              {
                type: 'button',
                style: 'link',
                height: 'sm',
                action: {
                  type: 'uri',
                  label: '詳細はこちら',
                  uri: shop['urls']['pc']
                }
              }
            ],
            flex: 0
          }
        }
      bubbles.push bubble
    end
    {
      type: 'carousel',
      contents: bubbles
    }
  end
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
