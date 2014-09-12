#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'

puts 'Starting to split articles'
Article.split_pdfs
puts 'Done splitting pdfs'