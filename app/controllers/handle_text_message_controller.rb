class HandleTextMessageController < LineBotController
  require_relative 'handle_location_message_controller'

  def handle_text_message(text)
    case
    when text.include?('今日のトピック')
      message = {
              type: 'text',
              text: '☆今話題になっているトピック☆' + "\n" + "\n" + tweet_topic.join
            }
    when text.include?('急上昇動画')
      message = {
              type: 'flex',
              altText: 'Youtubeの検索結果です。',
              contents: youtube_topic
            },
            {
              type: 'text',
              text: 'Youtubeで今話題になっている動画の検索結果です！気になる動画はありましたか？'
            }
    when text.include?('現在地検索')
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
    when text.include?('駅')
      results = HandleLocationMessageController.new.search_restaurants(text)
      if results.present?
              message = {
                type: 'flex',
                altText: 'よりみちできるカフェスポットの検索結果です！',
                contents: HandleLocationMessageController.new.restaurants_bubble(results)
              },
              {
                type: 'text',
                text: 'よりみちできるカフェスポットの検索結果です！気になるスポットは見つかりましたか？'
              }
      else
              reply_text = "「#{text}」に該当するお店は見つかりませんでした。"
              message = {
                type: 'text',
                text: reply_text
              }
      end
    else
      message = {
              type: 'text',
              text: 'こちらは自動応答BOTになるため個別での応答をすることはできません。当BOTに関するバグ報告やご要望などは【お問い合わせ】よりご連絡くださいませ。'
            }
    end
    message
  end

  def tweet_topic
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
      @image = item.snippet.thumbnails.high.url
      @url = item.id
      @title = item.snippet.title
      @description = item.snippet.description
      @channel_title = item.snippet.channel_title
      youtube_texts.push youtube_topic_bubble
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

end
