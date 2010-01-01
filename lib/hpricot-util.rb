# HTML utils that use hpricot
# Adapted from code by By Henrik Nyh (http://henrik.nyh.se), Les Hill 
# (http://blog.leshill.org)

require 'rubygems'
require 'html-cleaner'
require 'hpricot'
require 'active_support'

module FeedMe
  class HpricotUtil
    # Like the Rails _truncate_ helper but doesn't break HTML tags or entities.
    def truncate_html(html, words=15, truncate_string= "...")
      return if html.nil?
      doc = Hpricot(html.to_s)
      doc.inner_text.mb_chars.split.size >= words ? 
        doc.truncate(words, truncate_string).inner_html : html.to_s
    end

    # strip all tags from HTML
    def strip_html(html)
      (Hpricot.parse(html)/:"text()").to_s
    end

    # strip tags from HTML and truncate to a certain number of words
    def strip_truncate_html(input, words=15, truncate_string='...')
      strip_html(input).split[0..words].join(' ') + truncate_string
    end

    # sanitize HTML
    # todo: dup code to fix bugs
    def clean_html(html)
      FeedMe::HtmlCleaner.clean(html)
    end
  end
  
  @@instance = HpricotUtil.new
  
  def FeedMe.html_helper
    @@instance
  end
end

module HpricotTruncator
  module NodeWithChildren
    def truncate(words, truncate_string)
      return self if inner_text.mb_chars.split.size <= words
      truncated_node = dup
      truncated_node.name = name
      truncated_node.raw_attributes = raw_attributes
      truncated_node.children = []
      each_child do |node|
        break if words <= 0
        node_length = node.inner_text.mb_chars.split.size
        truncated_node.children << node.truncate(words, truncate_string)
        words -= node_length
      end
      truncated_node
    end
  end

  module TextNode
    def truncate(num_words, truncate_string)
      words = content.split
      self.content = (words.size <= num_words ?
        content : words[0..num_words-1].join(' ') + truncate_string).to_s
      self
    end
  end

  module IgnoredTag
    def truncate(max_length, ellipsis)
      self
    end
  end
end

Hpricot::Doc.send(:include,       HpricotTruncator::NodeWithChildren)
Hpricot::Elem.send(:include,      HpricotTruncator::NodeWithChildren)
Hpricot::Text.send(:include,      HpricotTruncator::TextNode)
Hpricot::BogusETag.send(:include, HpricotTruncator::IgnoredTag)
Hpricot::Comment.send(:include,   HpricotTruncator::IgnoredTag)