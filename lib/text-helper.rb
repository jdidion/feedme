# By Henrik Nyh <http://henrik.nyh.se> 2008-01-30.
# Free to modify and redistribute with credit.

require "rubygems"
require "hpricot"

# TODO: all uses of String#size should be replaced with String#chars#length
module TextHelper
  # Like the Rails _truncate_ helper but doesn't break HTML tags or entities.
  def TextHelper.truncate_html(text, max_length = 30, ellipsis = "...")
    text.size > max_length ? Hpricot(text).truncate(max_length).inner_html + ellipsis : text
  end
end

module HpricotTruncator
  module NodeWithChildren
    def truncate(max_length)
      return self if inner_text.size <= max_length
      truncated_node = self.dup
      truncated_node.children = []
      each_child do |node|
        remaining_length = max_length - truncated_node.inner_text.size
        break if remaining_length == 0
        truncated_node.children << node.truncate(remaining_length)
      end
      truncated_node
    end
  end

  module TextNode
    def truncate(max_length)
      # We're using String#scan because Hpricot doesn't distinguish entities.
      Hpricot::Text.new(content.scan(/&#?[^\W_]+;|./).first(max_length).join)
    end
  end

  module IgnoredTag
    def truncate(max_length)
      self
    end
  end
end

Hpricot::Doc.send(:include,       HpricotTruncator::NodeWithChildren)
Hpricot::Elem.send(:include,      HpricotTruncator::NodeWithChildren)
Hpricot::Text.send(:include,      HpricotTruncator::TextNode)
Hpricot::BogusETag.send(:include, HpricotTruncator::IgnoredTag)
Hpricot::Comment.send(:include,   HpricotTruncator::IgnoredTag)
