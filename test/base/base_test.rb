require File.dirname(__FILE__) + '/../test_helper'
class BaseTest < Test::Unit::TestCase
	def setup
		@rss092 = FeedMe.parse open(File.dirname(__FILE__) + '/../data/rss092.xml')
		@rss10  = FeedMe.parse open(File.dirname(__FILE__) + '/../data/rss10.rdf')
		@rss20  = FeedMe.parse open(File.dirname(__FILE__) + '/../data/rss20.xml')
		@atom   = FeedMe.parse open(File.dirname(__FILE__) + '/../data/atom.xml')
	end
	
	def test_channel
		assert_equal @rss092, @rss092.channel
		assert_equal @rss10, @rss10.channel
		assert_equal @rss20, @rss20.channel
		assert_equal @atom, @atom.feed
	end
	
	def test_items
		assert_kind_of Array, @rss092.items
		assert_kind_of Array, @rss10.item_array
		assert_kind_of Array, @rss20.items
		assert_kind_of Array, @atom.entries
	end
	
	def test_rss092
		assert_equal 1, @rss092.items.size
		assert_equal "Example Channel", @rss092.title
		assert_equal "http://example.com/", @rss092.channel.link
		assert_equal "http://example.com/1_less_than_2.html", @rss092.items.first.link
    assert_equal Time.parse("Wed Aug 24 13:33:34 UTC 2005"), @rss092.items.first.pubDate
	end

  def test_rss10
		assert_equal 1, @rss10.item_array.size
		assert_equal "Example Dot Org", @rss10.title
		assert_equal "http://www.example.org", @rss10.channel.link
		assert_equal "http://www.example.org/status/", @rss10.item_array.first.link
    assert_equal Time.parse("Wed Aug 24 13:33:34 UTC 2005"), @rss10.item_array.first.pubDate
	end

	def test_rss20
		assert_equal 1, @rss20.items.size
		assert_equal "Example Channel", @rss20.title
		assert_equal "http://example.com/", @rss20.channel.link
		assert_equal "http://example.com/1_less_than_2.html", @rss20.items.first.link
    assert_equal Time.parse("Wed Aug 24 13:33:34 UTC 2005"), @rss20.items.first.pubDate
	end
	
	def test_atom
		assert_equal 1, @atom.entries.size
		assert_equal "dive into mark", @atom.title_value
		assert_equal "http://example.org/", @atom.feed.link.href
		#puts @atom.inspect
		assert_equal "http://example.org/2005/04/02/atom", @atom.entries.first.link.href
	end
	
	def test_bad_feed
	  assert_raise(FeedMe::FeedMeError) { FeedMe.parse(open(File.dirname(__FILE__) + '/../data/not-rss.xml')) }
	end
end