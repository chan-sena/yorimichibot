class HandleLocationMessageController < LineBotController
  require_relative 'handle_text_message_controller'

  def handle_location_message(message)
    stations = stations(message['longitude'], message['latitude'])
      if stations.blank?
        return { type: 'text', text: '最寄駅がありません。'}
      end
          station_message = stations.map do |station|
            "🚃#{station['name']}駅   #{station['line']}(#{station['distance']})"
          end.join("\n")
          station_names = stations.map do |station|
            "#{station['name']}"
          end.uniq.first(2)
          reply_messages = {type: 'text',
                            text: '【最寄駅と最寄路線までの距離です】' + "\n" + station_message},
                           {type: 'template',
                            altText: 'カフェスポット検索中',
                            template: {
                              type: 'buttons',
                              text: '最寄駅周辺のカフェスポットを調べるにはこちらをタップ🔍',
                              actions: station_names.map do |name|
                                {type: 'message',
                                label: name + '駅',
                                text: name + '駅'}
                              end
                            }}
            reply_messages
  end

  def stations(longitude, latitude)
    uri = URI('https://express.heartrails.com/api/json')
    uri.query = URI.encode_www_form({
                                      method: 'getStations',
                                      x: longitude,
                                      y: latitude
                                    })
    res = Net::HTTP.get_response(uri)
    JSON.parse(res.body)['response']['station']
  end

  def search_restaurants(keyword)
    keyword_without_station = keyword.gsub(/駅/, '')
    uri = URI('https://webservice.recruit.co.jp/hotpepper/gourmet/v1/')
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
            url: shop['photo']['pc']['l'],
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

end
