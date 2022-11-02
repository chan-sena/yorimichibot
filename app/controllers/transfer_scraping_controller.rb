class TransferScrapingController < ApplicationController
#require 'open-uri'
#require 'nokogiri'
require 'mechanize'

  class Scraping
    def self.hoge
      agent = Mechanize.new
      page = agent.get('https://transit.yahoo.co.jp/search')
    end
  end

end
