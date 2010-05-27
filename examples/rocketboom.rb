#!/usr/bin/ruby
require 'rubygems'
require 'feedme'
require 'net/http'

def fetch(url)  
  response = Net::HTTP.get_response(URI.parse(url))
  case response
  when Net::HTTPSuccess
    response.body
  else
    response.error!
  end
end

# read from a file
#content = ""
#File.open('bad.rss', "r") do |file|
#  content = file.read
#end

# read from a url
#content = fetch('http://www.rocketboom.com/rss/hd.xml')
content = fetch('http://failbooking.com/feed/')

# create a new ParserBuilder
builder = FeedMe::ParserBuilder.new
# add a bang mod to wrap content to 50 columns
builder.default_transformation << :wrap_80

# parse the rss feed
rss = builder.parse(content)

# equivalent to rss.channel.title 
puts "#{rss.class} Feed: #{rss.title}"

# use a virtual method...this one a shortcut to rss.items.size
puts "#{rss.item_count} items"
rss.items.each do |item|
  puts
  # we can easily access the content of a mixed element
  puts "ID:    #{item.guid_value} (#{item.guid.isPermaLink})"
  puts "Date:  #{item.pubDate}"
  puts "Title: #{item.title}"
  # we can access all categories
  puts "Categories: #{item.category_array.join(', ')}" if item.category_array?
  # ! causes value to be modified according to prior specifications
  # ? checks for the presense of a tag/attribute
  puts "Description:\n#{item.description}" if item.description?
  # we can access attribute values just as easily as tag content
  puts "Enclosure: #{item.enclosure.url}" if item.enclosure?
  loc = 'media:content'
  mc = item.call_virtual_method("#{loc}_values".to_sym)
  puts mc.join(',')
end
