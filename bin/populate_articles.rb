#!/usr/bin/env ruby
require_relative '../environment.rb'

puts 'Starting to populate articles'
Article.connection.execute("truncate table articles")
Article.populate
puts 'Done populating articles'
