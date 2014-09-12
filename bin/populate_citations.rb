#!/usr/bin/env ruby
require_relative '../environment.rb'

puts 'Starting to populate citations'
Article.connection.execute("UPDATE articles SET citation = NULL, abstract = NULL")
puts 'Flushed all citations'
Article.populate_citations
Article.verify_dois
puts 'Done populating citations'