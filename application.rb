#!/usr/bin/env ruby
require 'sinatra'
require 'will_paginate/collection'

class ARTICLESEMANTICIZER < Sinatra::Base
  
  require File.join(File.dirname(__FILE__), 'environment')

  set :haml, :format => :html5
  set :public_folder, 'public'

  options = {
      tracker: ArticleSemanticizer::Config.google_ua_account,
      domain: ArticleSemanticizer::Config.google_ua_domain
      }
  use Rack::GoogleAnalytics, options if environment == :production

  helpers WillPaginate::Sinatra::Helpers
  helpers Sinatra::ContentFor

  helpers do
    def paginate(collection)
        options = {
         inner_window: 3,
         outer_window: 3,
         previous_label: '&laquo;',
         next_label: '&raquo;'
        }
       will_paginate collection, options
    end

    def h(text)
      Rack::Utils.escape_html(text)
    end
  end

  def sanitize_string_for_elasticsearch_string_query(str)
    # Escape special characters
    return if !str.present?
    escaped_characters = Regexp.escape('\\+-:*()[]{}!')
    str = str.gsub(/([#{escaped_characters}])/, '\\\\\1')

    # Replace AND, OR, NOT (note the upper case) with lower case equivalent when surrounded by word boundaries
    ['and', 'or', 'not'].each do |word|
      escaped_word = word.split('').map {|char| "\\#{char}" }.join('')
      str = str.gsub(/\s*\b(#{word.upcase})\b\s*/, " #{escaped_word} ")
    end

    # Remove odd quotes
    quote_count = str.count '"'
    str = str.gsub(/(.*)"(.*)/, '\1\"\3') if quote_count % 2 == 1
    str
  end
  
  def execute_search(type = 'article')
    @results = []
    searched_term = params[:q]
    geo = params[:geo]
    return if !(searched_term.present? || geo.present?)

    sort_year = params[:sort_year]
    page = (params[:page] || 1).to_i
    search_size = (params[:per] || 20).to_i
    clean_searched_term = sanitize_string_for_elasticsearch_string_query(searched_term)

    center = params[:c] || "0,0"
    radius = (params[:r] || 0).to_s + "km"
    bounds = (params[:b] || "0,0,0,0").split(",").map(&:to_f) rescue [0,0,0,0]
    polygon = YAML::load(params[:p] || "[[0,0]]").map{ |n| n.reverse } rescue []

    body = { query: { match_all: {} } }
    sort = ""
    sort = "year:asc" if sort_year == 'asc'
    sort = "year:desc" if sort_year == 'desc'

    fields = "id,citation.content"

    client = Elasticsearch::Client.new
    if searched_term.present?
      if searched_term.include?(":")
        components = searched_term.split(":",2)
        body = { query: { match: Hash[components[0], components[1]] } }
      elsif (type == 'scientific' || type == 'vernacular')
        body = { query: { match: { name: clean_searched_term } } }
        fields = "id,name"
      else
        body = {
          query: {
            bool: {
              should: [
                match: { "citation.scientific_names" => clean_searched_term, boost: 5.0 },
                match: { "abstract.scientific_names" => clean_searched_term, boost: 2.0 },
                match: { "full_text.scientific_names" => clean_searched_term, boost: 2.0 },
                match: { "citation.vernacular_names.name" => clean_searched_term, boost: 1.5 },
                match: { "abstract.vernacular_names.name" => clean_searched_term, boost: 1.5 },
                match: { "full_text.vernacular_names.name" => clean_searched_term, boost: 1.5 },
                match: { "citation.content" => clean_searched_term },
                match: { "abstract.content" => clean_searched_term },
                match: { "full_text.content" => clean_searched_term }
              ]
            }
          }
        }
      end
    end

    if geo.present?
      case geo
        when 'circle'
          body["filter"] = { geo_distance: { "full_text.places.location" => center, distance: radius } }
        when 'rectangle'
          body["filter"] = { geo_bounding_box: { "full_text.places.location" => { top_left: [bounds[1],bounds[2]], bottom_right: [bounds[3],bounds[0]] } } }
        when 'polygon'
          body["filter"] = { geo_polygon: { "full_text.places.location" => { points: polygon } } }
      end
    end

    from = (page -1) * search_size

    response = client.search index: ArticleSemanticizer::Config.elastic_index, type: type, fields: fields, from: from, size: search_size, sort: sort, body: body
    results = response["hits"].deep_symbolize_keys

    @results = WillPaginate::Collection.create(page, search_size, results[:total]) do |pager|
      pager.replace results[:hits]
    end
  end

  def get_article(id)
    article = nil
    client = Elasticsearch::Client.new
    begin
      response = client.get index: ArticleSemanticizer::Config.elastic_index, type: 'article', id: id
      article = response["_source"].deep_symbolize_keys
      if !ArticleSemanticizer::Config.enable_downloads
        article.delete(:pdf)
        article.delete(:txt)
      end
    rescue
    end
    @result = article
  end
  
  def format_names
    @results.map{ |n| n[:fields][:name][0] }.sort
  end
     
  get '/' do
    execute_search
    haml :home
  end
  
  get '/article/:id' do
    get_article(params[:id].to_i)
    haml :article
  end
  
  get '/api.?:format?' do
    execute_search
    case params[:format]
      when 'json'
        @results.to_json
    end
  end
  
  get '/scientific.json' do
    execute_search('scientific')
    format_names.to_json
  end

  get '/vernacular.json' do
    execute_search('vernacular')
    format_names.to_json
  end

  get '/about' do
    haml :about
  end

  get '/main.css' do
    content_type 'text/css', charset: 'utf-8'
    scss :main
  end
  
  run! if app_file == $0

end