# By Henrik Nyh <http://henrik.nyh.se> 2008-01-30.
# Free to modify and redistribute with credit.
# Word truncation and fixes by Les Hill <http://blog.leshill.org> 2009-06-02

require 'rubygems'
require 'hpricot'
require 'active_support'

module TextHelper
  # Like the Rails _truncate_ helper but doesn't break HTML tags or entities.
  def TextHelper.truncate_html(text, max_length = 30, ellipsis = "...")
    return if text.nil?
    doc = Hpricot(text.to_s)
    doc.inner_text.mb_chars.length > max_length ? doc.truncate(max_length, ellipsis).inner_html : text.to_s
  end

  def self.truncate_at_space(text, max_length, ellipsis = '...')
    l = [max_length - ellipsis.length, 0].max
    stop = text.rindex(' ', l) || 0
    (text.length > max_length ? text[0...stop] + ellipsis : text).to_s
  end
end

module HpricotTruncator
  module NodeWithChildren
    def truncate(max_length, ellipsis)
      return self if inner_text.mb_chars.length <= max_length
      truncated_node = dup
      truncated_node.name = name
      truncated_node.raw_attributes = raw_attributes
      truncated_node.children = []
      each_child do |node|
        break if max_length <= 0
        node_length = node.inner_text.mb_chars.length
        truncated_node.children << node.truncate(max_length, ellipsis)
        max_length = max_length - node_length
      end
      truncated_node
    end
  end

  module TextNode
    def truncate(max_length, ellipsis)
      self.content = TextHelper.truncate_at_space(content, max_length, ellipsis)
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