#!/usr/bin/env ruby
# encoding: utf-8

#use BHL_ENV to setup the environment: BHL_ENV=test ./resolving_bhl.rb

require_relative '../environment.rb'

if ARGV[0] == '--truncate'
  puts "Truncating data"
  Article.connection.execute("TRUNCATE TABLE resolved_canonical_forms")
  Article.connection.execute("TRUNCATE TABLE resolved_name_strings")
  Article.connection.execute("UPDATE name_strings SET status = 0")
end

resolver = ArticleSemanticizer::ResolverClient.new
resolver.batch_size = 50

rows_num = 1
until rows_num == 0
   rows_num = resolver.process_batch
end

# rows_num = 1
# until rows_num == 0
#   rows_num = resolver.process_failed_batches(50)
# end


