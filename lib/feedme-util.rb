module FeedMe
  # Pretty-print an object, with special formatting for hashes
  # and arrays.
  def FeedMe.pretty_to_s(obj, indent_step=2, indent=0, code=nil)
    new_indent = indent + indent_step
    space = ' ' * indent
    new_space = ' ' * new_indent
    str = ''
    if (obj.is_a?(FeedData) || obj.is_a?(Hash))
      str << "#{obj.fm_tag_name} " if obj.is_a?(FeedData)
      str << "{"
      obj.each_with_index do |item, index|
        key, value = code.call(*item) if code
        str << "\n#{new_space}"
        str << FeedMe.pretty_to_s(key, indent_step, new_indent, code)
        str << " => " 
        str << FeedMe.pretty_to_s(value, indent_step, new_indent, code)
        str << ',' unless index == obj.size-1
      end
      str << "\n#{space}}"
    elsif obj.is_a?(Array)
      str << "[" 
      obj.each_with_index do |value, index|
        str << "\n#{new_space}"
        str << FeedMe.pretty_to_s(value, indent_step, new_indent, code)
        str << ',' unless index == obj.size-1
      end
      str << "\n#{space}]"
    elsif obj.is_a? Symbol
      str << obj.inspect
    else
      str << obj.to_s.strip.inspect
    end
    return str
  end
end

class String
  def trunc(wordcount, tail='...')
    words = self.split
    truncated = words[0..(wordcount-1)].join(' ')
    truncated += tail if words.size > wordcount
    truncated
  end
end
