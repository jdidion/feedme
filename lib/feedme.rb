####################################################################################
# FeedMe v0.1
# 
# FeedMe is an easy to use parser for RSS and Atom files. It is based on SimpleRSS,
# but has some improvements that make it worth considering:
# 1. Support for attributes
# 2. Support for nested elements
# 3. Support for elements that appear multiple times
# 4. Syntactic sugar that makes it easier to get at the information you want
#
# One word of caution: FeedMe will be maintained only so long as SimpleRSS does not
# provide the above features. I will try to keep FeedMe's API compatible with 
# SimpleRSS so that it will be easy for users to switch if/when necessary.
####################################################################################

require 'cgi'
require 'time'

module FeedMe
  VERSION = "0.1"

  # constants for the feed type
  RSS  = :RSS
  ATOM = :ATOM

  # the key used to access the content element of a mixed tag
  CONTENT_KEY = :content

  def FeedMe.parse(source, options={})
    ParserBuilder.new.parse(source, options)
  end

  def FeedMe.parse_strict(source, options={})
    StrictParserBuilder.new.parse(source, options)
  end
  
  class ParserBuilder
    attr_accessor :rss_tags, :rss_item_tags, :atom_tags, :atom_entry_tags,
                  :date_tags, :value_tags, :ghost_tags, :aliases, 
                  :bang_mods, :bang_mod_fns

    # the promiscuous parser only has to know about tags that have nested subtags
    def initialize
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
      @value_tags = [ CONTENT_KEY, :href ]
  
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
    	@bang_mods = [ :stripHtml ]
    	@bang_mod_fns = {
    	  :stripHtml => proc {|str| str.gsub(/<\/?[^>]*>/, "").strip },
    	  :wrap      => proc {|str, col| str.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/, "\\1\\3\n").strip }
    	}
    end
    
    def all_rss_tags
      all_tags = rss_tags.dup
      all_tags[0][:item] = rss_item_tags.dup
      return all_tags
    end

    def all_atom_tags
      all_tags = atom_tags.dup
      all_tags[0][:entry] = atom_entry_tags.dup
      return all_tags
    end
    
    def parse(source, options={})
		  Parser.new(self, source, options)
	  end
  end

  class StrictParserBuilder < ParserBuilder
    attr_accessor :feed_ext_tags, :item_ext_tags 
    
    def initialize
      super()
      
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
        :'link+self', :'link+alternate', :'link+edit', 
        :'link+replies', :'link+related', :'link+enclosure',
        :'link+via', :rights, :subtitle
      ]
      @atom_entry_tags = [
        {
          :author       => person_tags, 
          :contributor  => person_tags
        },
        :id, :author, :title, :updated, :summary,           # required
        :category, :content, :contributor, :'link+self', 
        :'link+alternate', :'link+edit', :'link+replies', 
        :'link+related', :'link+enclosure', :published,
        :rights, :source
      ]
  
      # extensions
      @feed_ext_tags = [ 
        :'dc:date', :'feedburner:browserFriendly', 
        :'itunes:author', :'itunes:category'
      ]
      @item_ext_tags = [ 
        :'dc:date', :'dc:subject', :'dc:creator', 
        :'dc:title', :'dc:rights', :'dc:publisher', 
        :'trackback:ping', :'trackback:about',
        :'feedburner:origLink'
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
    
    def [](key)
      @data[key]
    end
    
    def []=(key, value)
      @data[key] = value
    end
    
    def to_s
      @data.to_s
    end
    
    def method_missing(name, *args)
      call_virtual_method(name, args)
    end
    
    protected 
  
    def clean_tag(tag)
    	tag.to_s.gsub(':','_').intern
  	end
  
    # generate a name for the array variable corresponding to a single-value variable
    def arrayize(key)
      return key + '_array'
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
    def call_virtual_method(name, args, history=[])
      # make sure we don't get stuck in an infinite loop
      history.each do |call|
        if call[0] == fm_tag_name and call[1] == name
          puts name
          puts self.inspect
          raise FeedMe::InfiniteCallLoopError.new(name, history) 
        end
      end
      history << [ fm_tag_name, name ]
              
      raw_name = name
      name = clean_tag(name)
      name_str = name.to_s
      array_key = clean_tag(arrayize(name.to_s))
      
      if name_str[-1,1] == '?'
        !call_virtual_method(name_str[0..-2], args, history).nil? rescue false
      elsif name_str[-1,1] == '!'
        value = call_virtual_method(name_str[0..-2], args, history)
        fm_builder.bang_mods.each do |bm|
          parts = bm.to_s.split('_')
          bm_key = parts[0].to_sym
          next unless fm_builder.bang_mod_fns.key?(bm_key)
          value = fm_builder.bang_mod_fns[bm_key].call(value, *parts[1..-1])
        end
        return value
      elsif key? name
        self[name]
      elsif key? array_key
        self[array_key].first
      elsif name_str =~ /(.+)_value/
        value = call_virtual_method($1, args, history)
        if value.is_a?(FeedData)
          fm_builder.value_tags.each do |tag|
            return value.call_virtual_method(tag, args, history) rescue nil
          end
        else 
          value
        end
      elsif name_str =~ /(.+)_count/
        call_virtual_method(clean_tag(arrayize($1)), args, history).size
      elsif name_str.include?("+")
  		  tag_data = tag.to_s.split("+")
  		  rel = tag_data[1]
  		  call_virtual_method(clean_tag(arrayize(tag_data[0])), args, history).each do |elt|
  		    next unless elt.is_a?(FeedData) and elt.rel?
  		    return elt if elt.rel.casecmp(rel) == 0
		    end
		  elsif fm_builder.aliases.key? name
        name = fm_builder.aliases[name]
        method(name).call(*args) rescue call_virtual_method(name, args, history)
      elsif fm_tag_name == :items      # special handling for RDF items tag
        self[:'rdf:li_array'].method(raw_name).call(*args)
      elsif fm_tag_name == :'rdf:li'   # special handling for RDF li tag
        uri = self[:'rdf:resource']
        fm_parent.fm_parent.item_array.each do |item|
          if item[:'rdf:about'] == uri
            return item.call_virtual_method(name, args, history)
          end
        end
      else
        raise NameError.new("No such method #{name}", name)
      end
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
      array_var = clean_tag(arrayize(key.to_s))
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