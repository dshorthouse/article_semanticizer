#!/usr/bin/env ruby
require 'pp'
require_relative '../environment.rb'

if ARGV[0] == '--truncate'
  puts "Truncating data"
  Entity.connection.execute("UPDATE articles SET entity_status = NULL")
  Entity.connection.execute("TRUNCATE TABLE article_entities")
  Entity.connection.execute("TRUNCATE TABLE entities")
end

Entity.populate