require 'bundler'
require 'ostruct'
require 'logger'
require 'mysql2'
require 'active_record'
require 'active_support/all'
require 'composite_primary_keys'
require 'rest_client'
require 'json'
require 'find'
require 'unicode_utils'
require 'addressable/uri'
require 'nokogiri'
require 'sanitize'
require 'htmlentities'
require 'elasticsearch'
require 'haml'
require 'sass'
require 'rinku'
require 'will_paginate'
require 'will_paginate/view_helpers/sinatra'
require 'rinku'
require 'docsplit'
require 'sinatra'
require 'sinatra/content_for'
require 'yaml'
require 'rack/google-analytics'

module ArticleSemanticizer
  
  def self.symbolize_keys(obj)
    if obj.class == Array
      obj.map {|o| ArticleSemanticizer.symbolize_keys(o)}
    elsif obj.class == Hash
      obj.inject({}) {|res, data| res.merge(data[0].to_sym => ArticleSemanticizer.symbolize_keys(data[1]))}
    else
      obj
    end
  end

  root_path = File.expand_path(File.dirname(__FILE__))
  CONF_DATA = ArticleSemanticizer.symbolize_keys(YAML.load(open(File.join(root_path, 'config.yml')).read))
  conf = CONF_DATA
  environment = ENV['ARTICLESEMANTICIZER_DEV'] || 'development'
  Config = OpenStruct.new(
                 :gnrd_api_url => conf[:gnrd_api_url],
                 :resolver_api_url => conf[:resolver_api_url],
                 :crossref_api_url => conf[:crossref_api_url],
                 :biblio_api_url => conf[:biblio_api_url],
                 :eol_search_api_url => conf[:eol_search_api_url],
                 :eol_pages_api_url => conf[:eol_pages_api_url],
                 :alchemy_api_url => conf[:alchemy_api_url],
                 :alchemy_api_key => conf[:alchemy_api_key],
                 :root_path => root_path,
                 :root_file_path => conf[:root_file_path],
                 :environment => environment,
                 :carousel_size => conf[:carousel_size],
                 :elastic_server => conf[:elastic_server],
                 :elastic_index => conf[:elastic_index],
                 :enable_downloads => conf[:enable_downloads],
                 :google_ua_account => conf[:google_ua_account],
                 :google_ua_domain => conf[:google_ua_domain]
               )
  # load models
  db_settings = conf[Config.environment.to_sym]
  # ActiveRecord::Base.logger = Logger.new(STDOUT, :debug) if environment == 'test'
  ActiveRecord::Base.establish_connection(db_settings)
  $LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))
  $LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib', 'article_semanticizer'))
  $LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'models'))
  Dir.glob(File.join(File.dirname(__FILE__), 'lib', '**', '*.rb')) { |lib|   require File.basename(lib, '.*') }
  Dir.glob(File.join(File.dirname(__FILE__), 'models', '*.rb')) { |model| require File.basename(model, '.*') }
end

