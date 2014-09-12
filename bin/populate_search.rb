#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'

if ARGV[0] == '--flush'
  puts "Flushing the #{ArticleSemanticizer::Config.elastic_index} index"
  index = ArticleSemanticizer::ElasticIndexer.new
  index.delete
  puts "Flushed"
end

if ARGV[0] == '--rebuild'
  index = ArticleSemanticizer::ElasticIndexer.new
  puts "Flushing the #{ArticleSemanticizer::Config.elastic_index} index"
  index.delete
  puts "Creating the #{ArticleSemanticizer::Config.elastic_index} index"
  index.create
  index.import_scientific_names
  index.import_vernacular_names
  index.import_articles
  puts "Refreshing the index..."
  index.refresh
  puts "Finished indexing #{ArticleSemanticizer::Config.elastic_index}"
end