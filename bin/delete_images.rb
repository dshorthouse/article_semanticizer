#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'

puts 'Starting to delete images'
Article.delete_images
puts 'Done deleting images'