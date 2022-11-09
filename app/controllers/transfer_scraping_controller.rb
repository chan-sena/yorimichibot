class TransferScrapingController < ApplicationController
#require 'open-uri'
#require 'nokogiri'
require 'mechanize'

  class Scraping
    def self.hoge
      agent = Mechanize.new
      # page = agent.get('https://transit.yahoo.co.jp/search/print?from=#{departure}&flation=&to=#{destination}')
      page = agent.get('https://transit.yahoo.co.jp/search/result?from=%E6%B1%9F%E5%8F%A4%E7%94%B0&to=%E6%96%B0%E5%AE%BF&fromgid=&togid=&flatlon=&tlatlon=&y=2022&m=11&d=07&hh=17&m1=2&m2=0&type=1&ticket=ic&expkind=1&userpass=1&ws=3&s=0&al=1&shin=1&ex=1&hb=1&lb=1&sr=1')
      elments = page.search('#route03 .station dl dt').inner_text
      puts elements
    end
  end

end
