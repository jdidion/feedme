####################################################################################
# FeedMe v0.4
# 
# FeedMe is an easy to use parser for RSS and Atom files. It is based on SimpleRSS,
# but has some improvements that make it worth considering:
# 1. Support for attributes
# 2. Support for nested elements
# 3. Support for elements that appear multiple times
# 4. Syntactic sugar that makes it easier to get at the information you want
#
# The parse methods (as well as the constructors) support a few options:
# :empty_string_for_nil => false # return the empty string instead of a nil value
# :error_on_missing_key => false # raise an error if a specified key or virtual
# method does not exist (otherwise nil is returned)
####################################################################################

require 'cgi'
require 'time'

class String
  def trunc(wordcount, tail='...')
    words = self.split
    truncated = words[0..(wordcount-1)].join(' ')
    truncated += tail if words.size > wordcount
    truncated
  end
end

module FeedMe
  VERSION = "0.5.2"

  # constants for the feed type
  RSS  = :RSS
  ATOM = :ATOM

  # the key used to access the content element of a mixed tag
  CONTENT_KEY = :content

  def FeedMe.parse(source, options={})
    ParserBuilder.new(options).parse(source)
  end

  def FeedMe.parse_strict(source, options={})
    StrictParserBuilder.new(options).parse(source)
  end
  
  def FeedMe.pretty_to_s(obj, indent_step=2, indent=0, code=nil)
    new_indent = indent + indent_step
    space = ' ' * indent
    new_space = ' ' * new_indent
    str = ''
    if (obj.is_a?(FeedData) || obj.is_a?(Hash))
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
    else
      str << obj.to_s.strip.inspect
    end
    return str
  end
  
  class ParserBuilder
    attr_accessor :options, 
                  :rss_tags, :rss_item_tags, :atom_tags, :atom_entry_tags,
                  :date_tags, :value_tags, :ghost_tags, :aliases, 
                  :default_transformation, :transformations, :transformation_fns

    def initialize(options={})
      @options = options
      
      # rss tags
    	@rss_tags = [
    	  {
    		  :image     => nil,
          :textInput => nil,
          :skipHours => nil,
          :skipDays  => nil,
          :items     => [{ :'rdf:Seq' => nil }],
         #:item      => @rss_item_tags
    		}
    	]
      @rss_item_tags = [ {} ]

      #atom tags
      @atom_tags = [
        {
          :author       => nil,
          :contributor  => nil,
         #:entry        => @atom_entry_tags
        }
      ]
      @atom_entry_tags = [
        {
          :author       => nil, 
          :contributor  => nil
        }
      ]
    
      # tags whose value is a date
      @date_tags = [ :pubDate, :lastBuildDate, :published, :updated, :'dc:date', :expirationDate ]
  
      # tags that can be used as the default value for a tag with attributes
      @value_tags = [ CONTENT_KEY, :href, :url ]
  
      # tags that don't become part of the parsed object tree
      @ghost_tags = [ :'rdf:Seq' ]
    
      # tag/attribute aliases
    	@aliases = {
    	  :items        => :item_array,
    	  :item_array   => :entry_array,
    	  :entries      => :entry_array,
    	  :entry_array  => :item_array,
    	  :link         => :'link+self'
    	}
	
    	# bang mods
    	@default_transformation = [ :stripHtml ]
    	@transformations = {}
    	@transformation_fns = {
    	  :stripHtml => proc {|str|     # remove all HTML tags
    	    str.gsub(/<\/?[^>]*>/, "").strip 
    	  },
    	  :cleanHtml => proc {|str|     # clean HTML content using FeedNormalizer's HtmlCleaner class 
    	    begin
    	      require 'feed-normalizer'
    	      FeedNormalizer::HtmlCleaner.clean(str)
    	    rescue
    	      str
    	    end  
    	  }, 
    	  :wrap => proc {|str, col|     # wrap text at a certain number of characters (respecting word boundaries)
    	    str.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/, "\\1\\3\n").strip 
    	  },
    	  :trunc => proc {|str, wordcount|  # truncate text, respecting word boundaries
    	    str.trunc(wordcount)
        },
        :truncHtml => proc {|str, wordcount| # truncate text but leave enclosing HTML tags
          if str =~ /(<.+?>)(.+?)(<.*)/
            $1 + $2.trunc(wordcount) + $3
          else
            str.trunc(wordcount)
          end
        }
    	}
    end
    
    # Prepare tag list for an RSS feed.
    def all_rss_tags
      all_tags = rss_tags.dup
      all_tags[0][:item] = rss_item_tags.dup
      return all_tags
    end

    # Prepare tag list for an Atom feed.
    def all_atom_tags
      all_tags = atom_tags.dup
      all_tags[0][:entry] = atom_entry_tags.dup
      return all_tags
    end
    
    # Add aliases so that Atom feed elements can be accessed
    # using the names of their RSS counterparts.
    def emulate_rss!
      aliases.merge!({
        :guid           => :id,       # this alias never actually gets used; see FeedData#id
        :copyright      => :rights,
        :pubDate        => [ :published, :updated ],
        :lastBuildDate  => [ :updated, :published ],
        :description    => [ :content, :summary ],
        :managingEditor => [ :'author/name', :'contributor/name' ],
        :webMaster      => [ :'author/name', :'contributor/name' ],
        :image          => [ :icon, :logo ]
      })
    end
    
    # Add aliases so that RSS feed elements can be accessed
    # using the names of their Atom counterparts.
    def emulate_atom!
      aliases.merge!({
        :rights       => :copyright,
        :content      => :description,
        :contributor  => :author,
        :id           => [ :guid_value, :link ],
        :author       => [ :managingEditor, :webMaster ],
        :updated      => [ :lastBuildDate, :pubDate ],
        :published    => [ :pubDate, :lastBuildDate ],
        :icon         => :'image/url',
        :logo         => :'image/url',
        :summary      => :'description_trunc'
      })
    end
    
    def parse(source)
		  Parser.new(self, source, options)
	  end
  end

  class StrictParserBuilder < ParserBuilder
    attr_accessor :feed_ext_tags, :item_ext_tags, :rels 
    
    def initialize(options={})
      super(options)
      
      # rss tags
    	@rss_tags = [
    	  {
    		  :image     => [ :url, :title, :link, :width, :height, :description ],
          :textInput => [ :title, :description, :name, :link ],
          :skipHours => [ :hour ],
          :skipDays  => [ :day ],
          :items     => [ 
            {
              :'rdf:Seq' => [ :'rdf:li' ]
            },
            :'rdf:Seq' 
          ],
         #:item      => @item_tags
    		},
    		:title, :link, :description,                          # required
    		:language, :copyright, :managingEditor, :webMaster,   # optional
    		:pubDate, :lastBuildDate, :category, :generator,
    		:docs, :cloud, :ttl, :rating,
    		:image, :textInput, :skipHours, :skipDays, :item,     # have subtags
    		:items
    	]
      @rss_item_tags = [
        {},
        :title, :description,                                 # required
        :link, :author, :category, :comments, :enclosure,     # optional
        :guid, :pubDate, :source, :expirationDate
    	]

      #atom tags
      person_tags = [ :name, :uri, :email ]
      @atom_tags = [
        {
          :author       => person_tags,
          :contributor  => person_tags,
         #:entry        => @entry_tags
        },
        :id, :author, :title, :updated,                     # required
        :category, :contributor, :generator, :icon, :logo,  # optional
        :link, :rights, :subtitle
      ]
      @atom_entry_tags = [
        {
          :author       => person_tags, 
          :contributor  => person_tags
        },
        :id, :author, :title, :updated, :summary,           # required
        :category, :content, :contributor, :link, 
        :published, :rights, :source
      ]
  
      @rels = {
        :link => [ 'self', 'alternate', 'edit', 'replies', 'related', 'enclosure', 'via' ]
      }
  
      # extensions
      @feed_ext_tags = [ 
        :'dc:date', :'feedburner:browserFriendly', 
        :'itunes:author', :'itunes:category'
      ]
      @item_ext_tags = [ 
        :'dc:date', :'dc:subject', :'dc:creator', 
        :'dc:title', :'dc:rights', :'dc:publisher', 
        :'trackback:ping', :'trackback:about',
        :'feedburner:origLink', :'media:content',
        :'content:encoded'
      ]
    end
    
    def all_rss_tags
      all_tags = rss_tags + (feed_ext_tags or [])
      all_tags[0][:item] = rss_item_tags + (item_ext_tags or [])
      return all_tags
    end
    
    def all_atom_tags
      all_tags = atom_tags + (feed_ext_tags or [])
      all_tags[0][:entry] = atom_entry_tags + (item_ext_tags or [])
      return all_tags
    end
	end
  
  class FeedData
    attr_reader :fm_tag_name, :fm_parent, :fm_builder
    
    def initialize(tag_name, parent, builder, attrs = {})
      @fm_tag_name = tag_name
      @fm_parent = parent
      @fm_builder = builder
      @data = attrs.dup
    end
    
    def key?(key)
      @data.key?(key)
    end
    
    def keys
      @data.keys
    end
    
    def each
      @data.each {|key, value| yield(key, value) }
    end
    
    def each_with_index
      @data.each_with_index {|key, value, index| yield(key, value, index) }
    end
    
    def size
      @data.size
    end
    
    def [](key)
      @data[key]
    end
    
    def []=(key, value)
      @data[key] = value
    end
    
    # special handling for atom id tags, due to conflict with
    # ruby's Object#id method
    def id
      key?(:id) ? self[:id] : call_virtual_method(:id)
    end
    
    def to_s
      to_indented_s
    end
    
    def to_indented_s(indent_step=2)
      FeedMe.pretty_to_s(self, indent_step, 0, Proc.new do |key, value| 
        (value.is_a?(Array) && value.size == 1) ? [unarrayize(key), value.first] : [key, value]
      end)
    end
    
    def method_missing(name, *args)
      result = begin
        call_virtual_method(name, args)
      rescue NameError
        raise if fm_builder.options[:error_on_missing_key]
      end
      result = '' if result.nil? and fm_builder.options[:empty_string_for_nil]
      result
    end
    
    # There are several virtual methods for each attribute/tag.
    # 1. Tag/attribute name: since tags/attributes are stored as arrays,
    # the instance variable name is the tag/attribute name followed by
    # '_array'. The tag/attribute name is actually a virtual method that
    # returns the first element in the array.
    # 2. Aliases: for tags/attributes with aliases, the alias is a virtual
    # method that simply forwards to the aliased method.
    # 3. Any name that ends with a '?' returns true if the name without 
    # the '?' is a valid method and has a non-nil value.
    # 4. Any name that ends with a '!' returns the value of the name 
    # without the '!', modified by the currently active set of bang mods
    # 5. Tag/attribute name + '_value': returns the content portion of
    # an element if it has both attributes and content, , or to return the
    # default attribute (defined by the value_tags property). Otherwise
    # equivalent to just the tag/attribute name.
    # 6. Tag/attribute name + '_count': shortcut for tag/attribute 
    # array.size.
    # 7. If the tag name is of the form "tag+rel", the tag having the 
    # specified rel value is returned
    def call_virtual_method(sym, args=[], history=[])
      # make sure we don't get stuck in an infinite loop
      history.each do |call|
        if call[0] == fm_tag_name and call[1] == sym
          #puts sym
          #puts self.inspect
          raise FeedMe::InfiniteCallLoopError.new(sym, history) 
        end
      end
      history << [ fm_tag_name, sym ]
              
      name = clean_tag(sym)
      name_str = name.to_s
      array_key = arrayize(name.to_s)
      
      result = if key? name
        self[name]
      elsif key? array_key
        self[array_key].first
      elsif name_str[-1,1] == '?'
        !call_virtual_method(name_str[0..-2], args, history).nil? rescue false
      elsif name_str[-1,1] == '!'
        transform(fm_builder.default_transformation, name_str[0..-2], args, history)
      elsif name_str =~ /(.+)_value/
        obj = call_virtual_method($1, args, history)
        value = obj
        if obj.is_a?(FeedData)
          fm_builder.value_tags.each do |tag|
            value = obj.call_virtual_method(tag, args, history) rescue next
            break unless value.nil?
          end
        end
        value
      elsif name_str =~ /(.+)_count/
        call_virtual_method(arrayize($1), args, history).size
      elsif name_str =~ /(.+)_(.+)/ && fm_builder.transformations.key?($2)
        transform(fm_builder.transformations[$2], $1, args, history)
      elsif name_str.include?('/')    # this is only intended to be used internally 
        value = self
        name_str.split('/').each do |p|
          parts = p.split('_')
          name = clean_tag(parts[0])
          new_args = parts.size > 1 ? parts[1..-1] : args
          value = (value.method(name).call(*new_args) rescue value.call_virtual_method(name, new_args, history)) rescue nil
          break if value.nil?
        end
        value
      elsif name_str.include?('+')
  		  name_data = name_str.split('+')
  		  rel = name_data[1]
  		  value = nil
  		  call_virtual_method(arrayize(name_data[0]), args, history).each do |elt|
  		    next unless elt.is_a?(FeedData) and elt.rel?
  		    value = elt if elt.rel.casecmp(rel) == 0
  		    break unless value.nil?
		    end
		    value
		  elsif fm_builder.aliases.key? name
        names = fm_builder.aliases[name]
        names = [names] unless names.is_a? Array
        value = nil
        names.each do |name|
          value = (method(name).call(*args) rescue call_virtual_method(name, args, history)) rescue next
          break unless value.nil?
        end
        value
      elsif fm_tag_name == :items      # special handling for RDF items tag
        self[:'rdf:li_array'].method(sym).call(*args)
      elsif fm_tag_name == :'rdf:li'   # special handling for RDF li tag
        uri = self[:'rdf:resource']
        value = nil
        fm_parent.fm_parent.item_array.each do |item|
          value = item.call_virtual_method(name, args, history) if item[:'rdf:about'] == uri
          break unless value.nil?
        end
      else
        nil
      end

      raise NameError.new("No such method #{name}", name) if result.nil?

      result
    end
    
    protected 
  
    def clean_tag(tag)
    	tag.to_s.gsub(':','_').intern
  	end
  
    # generate a name for the array variable corresponding to a single-value variable
    def arrayize(key)
      clean_tag(key.to_s + '_array')
    end
    
    def unarrayize(key)
      clean_tag(key.to_s.gsub('_array', ''))
    end
    
    private 
    
    def transform(trans_array, key, args, history)
      value = call_virtual_method(key, args, history)
      trans_array.each do |t|
        parts = t.to_s.split('_')
        t_name = parts[0].to_sym
        trans = fm_builder.transformation_fns[t_name] or
          raise NameError.new("No such transformation #{t_name}", t_name)
        if value.is_a? Array
          value = value.collect {|x| trans.call(x, *parts[1..-1]) }
        else  
          value = trans.call(value, *parts[1..-1])
        end
      end
      value
    end
  end

  class Parser < FeedData
    attr_reader :fm_source, :fm_options, :fm_type, :fm_tags, :fm_unparsed
  
    def initialize(builder, source, options={})
      super(nil, nil, builder)
  		@fm_source = source.respond_to?(:read) ? source.read : source.to_s
      @fm_options = Hash.new.update(options)
      @fm_parsed = []
      @fm_unparsed = []
  		parse
  	end
  
    def channel() self end
    alias :feed :channel
  
    def fm_tag_name
      @fm_type == FeedMe::RSS ? 'channel' : 'feed'
    end
  
    private
  
    def parse
      # RSS = everything between channel tags + everthing between </channel> and </rdf> if this is an RDF document
      if @fm_source =~ %r{<(?:.*?:)?(?:rss|rdf)(.*?)>.*?<(?:.*?:)?channel(.*?)>(.+)</(?:.*?:)?channel>(.*)</(?:.*?:)?(?:rss|rdf)>}mi
        @fm_type = FeedMe::RSS
        @fm_tags = fm_builder.all_rss_tags
        attrs = parse_attributes($1, $2)
        attrs[:version] ||= '1.0';
        parse_content(self, attrs, $3 + nil_safe_to_s($4), @fm_tags)
      # Atom = everthing between feed tags
      elsif @fm_source =~ %r{<(?:.*?:)?feed(.*?)>(.+)</(?:.*?:)?feed>}mi
        @fm_type = FeedMe::ATOM
        @fm_tags = fm_builder.all_atom_tags
        parse_content(self, parse_attributes($1), $2, @fm_tags)
      else
        raise FeedMeError, "Poorly formatted feed"
      end
  	end

  	def parse_content(parent, attrs, content, tags)
  	  # add attributes to parent
  	  attrs.each_pair {|key, value| add_tag(parent, key, unescape(value)) }
  
  	  # the first item in a tag array may be a hash that defines tags that have subtags
  	  first_tag = 0
  	  if !tags.nil? && tags[0].is_a?(Hash)
  	    sub_tags = tags[0]
  	    first_tag = 1
      end
  
  	  # split the content into elements
  	  elements = {}
  	  # TODO: this will break if a namespace is used that is not rss: or atom: 	  
  	  content.scan( %r{(<(?:rss:|atom:)?([^ >]+)([^>]*)(?:/>|>(.*?)</(?:rss:|atom:)?\2>))}mi ) do |match|
  	    # \1 = full content (from start to end tag), \2 = tag name
  	    # \3 = attributes, and \4 = content between tags
  	    key = clean_tag(match[1])
  	    value = [parse_attributes(match[2]), match[3]]
  	    if elements.key? key
  	      elements[key] << value
  	    else
  	      elements[key] = [value]
  	    end
  	  end
      
      # check if this is a promiscuous parser
      if tags.nil? || tags.empty? || (tags.size == 1 && first_tag == 1)
        tags = elements.keys
        first_tag = 0
      end
      
  	  # iterate over all tags (some or all of which may not be present)
  	  tags[first_tag..-1].each do |tag|
  	    key = clean_tag(tag)
  	    element_array = elements.delete(tag) or next
  	    @fm_parsed << key

  		  element_array.each do |elt|
  		    attrs = elt[0]
  		    rels = fm_builder.rels[key] if fm_builder.respond_to?(:rels)
  		    
  		    # if a list of accepted rels is specified, only parse this tag
  		    # if its rel attribute is inlcuded in the list
  		    next unless rels.nil? || elt[0].nil || !elt[0].rel? || rels.include?(elt[0].rel)
  		    
  		    if !sub_tags.nil? && sub_tags.key?(key)
  		      if fm_builder.ghost_tags.include? key
  		        new_parent = parent
  		      else
  		        new_parent = FeedData.new(key, parent, fm_builder)
  		        add_tag(parent, key, new_parent)
  		      end
  		      parse_content(new_parent, elt[0], elt[1], sub_tags[key])
  		    else
  		      add_tag(parent, key, clean_content(key, elt[0], elt[1], parent))
  		    end
  		  end
  		end
  		
  		@fm_unparsed += elements.keys
  		
  		@fm_parsed.uniq!
  		@fm_unparsed.uniq!
  	end

    def add_tag(hash, key, value)
      array_var = arrayize(key.to_s)
      if hash.key? array_var
        hash[array_var] << value
      else
        hash[array_var] = [value]
      end
    end

    # used to normalize attribute names
    def format_tag(tag)
      camelize(underscore(tag).downcase, false)
    end

  	def clean_content(tag, attrs, content, parent)
  		content = content.to_s
  		if fm_builder.date_tags.include? tag
  			content = Time.parse(content) rescue unescape(content)
  		else 
  			content = unescape(content)
  		end
  
      unless attrs.empty?
        hash = FeedData.new(tag, parent, fm_builder, attrs)
        if !content.empty?
          hash[FeedMe::CONTENT_KEY] = content
        end
        return hash
      end
  
      return content
  	end

    def parse_attributes(*attrs)
      hash = {}
      attrs.each do |a|
        next if a.nil?
        # pull key/value pairs out of attr string
        array = a.scan(/(\w+)=['"]?([^'"]+)/)
        # unescape values
        array = array.collect {|key, value| [clean_tag(format_tag(key)), unescape(value)]}
        hash.merge! Hash[*array.flatten]
      end
      return hash
    end
  
    def unescape(content)
      content = CGI.unescapeHTML(content)

      query = content.match(/^(http:.*\?)(.*)$/)
      content = query[1] + CGI.unescape(query[2]) if query
      
      cdata = content.match(%r{<!\[CDATA\[(.*)\]\]>}mi)
      content = cdata[1] if cdata
      
      return content
  
    	#if content =~ /([^-_.!~*'()a-zA-Z\d;\/?:@&=+$,\[\]]%)/n then
    	# CGI.unescapeHTML(content).gsub(/(<!\[CDATA\[|\]\]>)/,'').strip
    	#else
    	#	content.gsub(/(<!\[CDATA\[|\]\]>)/,'').strip
    	#end
    end

    def underscore(camel_cased_word)
      camel_cased_word.to_s.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
    end

    def camelize(lower_case_and_underscored_word, first_letter_in_uppercase = true)
      if first_letter_in_uppercase
        lower_case_and_underscored_word.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
      else
        lower_case_and_underscored_word[0,1].downcase + camelize(lower_case_and_underscored_word)[1..-1]
      end
    end
    
    def nil_safe_to_s(obj)
      obj.nil? ? '' : obj.to_s
    end
  end
		
  class FeedMeError < StandardError
  end
  
  class InfiniteCallLoopError < StandardError
    attr_reader :name, :history
    
    def initialize(name, history)
      @name = name
      @history = history
    end
  end  
end