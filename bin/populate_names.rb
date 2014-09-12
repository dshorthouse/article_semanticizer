#!/usr/bin/env ruby
require 'pp'
require_relative '../environment.rb'

carousel = ArticleSemanticizer::Carousel.new
carousel.rebuild_names_hash
carousel.populate
until carousel.carousel_ary.empty?
  pp carousel.carousel_ary
  carousel.send_content
  sleep(5)
  carousel.get_names
  carousel.populate
end