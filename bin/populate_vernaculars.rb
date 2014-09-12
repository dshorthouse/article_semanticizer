#!/usr/bin/env ruby
require 'pp'
require_relative '../environment.rb'

if ARGV[0] == '--truncate'
  puts "Truncating data"
  Vernacular.connection.execute("UPDATE resolved_canonical_forms SET vernacular_status = NULL")
  Vernacular.connection.execute("TRUNCATE TABLE vernaculars")
  Vernacular.connection.execute("TRUNCATE TABLE resolved_canonical_vernaculars")
end

Vernacular.populate