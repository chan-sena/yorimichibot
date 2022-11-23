class LineBotController < ApplicationController
  require 'mechanize'

  protect_from_forgery except:[:callback]
  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      return head :bad_request
    end
    events = client.parse_events_from(body)
    events.each do |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          transfer_create_message(event.message['text'])
          message = {
            type: 'text',
            text: event.message['text']
          }
          client.reply_message(event['replyToken'], message)
        end
      end
    end
    head :ok
  end

  private
    def client
      @client ||= Line::Bot::Client.new { |config|
        config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
        config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
      }
    end

    def transfer_create_message(departure, destination)
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
