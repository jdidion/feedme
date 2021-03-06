require 'cgi'
require 'time'
require 'feedme-util'

module FeedMe
  # The value of Parser#fm_type for RSS feeds.
  RSS  = :RSS
  # The value of Parser#fm_type for RDF (RSS 1.0) feeds.
  RDF  = :RDF
  # The value of Parser#fm_type for Atom feeds.
  ATOM = :ATOM

  # The key used to access the content element of a mixed tag.
  CONTENT_KEY = :content

  # Helper libraries for HTML functions
  NOKOGIRI_HELPER = 'nokogiri-util.rb'
  HPRICOT_HELPER = 'hpricot-util.rb'

  # default rels to accept, in order of preference
  DEFAULT_RELS = [ 'self', 'alternate', 'enclosure', 'related', 'edit', 'replies', 'via' ]

  # Parse a feed using the promiscuous parser.
  def FeedMe.parse(source, options={})
    ParserBuilder.new(options).parse(source)
  end

  # Parse a feed using the strict parser.
  def FeedMe.parse_strict(source, options={})
    StrictParserBuilder.new(options).parse(source)
  end
  
  # This class is used to create promiscuous parsers.
  class ParserBuilder
    # The options passed to this ParserBuilder's constructor.
    attr_reader :options 
    # The tags that are parsed for RSS feeds.
    attr_accessor :rss_tags
    # The subtags of item elements that are parsed for RSS feeds.
    attr_accessor :rss_item_tags
    # The tags that are parsed for Atom feeds.
    attr_accessor :atom_tags
    # The subtags of entry elements that are parsed for Atom feeds.
    attr_accessor :atom_entry_tags
    # The names of tags that should be parsed as date values.
    attr_accessor :date_tags
    # An array of names of attributes/subtags whose values can be
    # used as the default value of a mixed element.
    attr_accessor :value_tags
    # Tags to use for element value when specific tag isn't specified
    attr_accessor :default_value_tags
    # A hash of functions for selecting the correct value to return when a tags 
    # has multiple values and the singluar accessor is called
    attr_accessor :value_selectors
    # Value selector to use if there is no value selector defined for a tag
    attr_accessor :default_value_selector
    # A hash of attribute/tag name aliases.
    attr_accessor :aliases
    # An array of the transformation functions applied when the !
    # suffix is added to the attribute/tag name.
    attr_accessor :default_transformation
    # Mapping of transformation names to functions. Each key is a
    # suffix that can be appended to an attribute/tag name, and
    # the value is an array of transformation function names that
    # are applied when that transformation is used.
    attr_accessor :transformations
    # Mapping of transformation function names to Procs.
    attr_accessor :transformation_fns
    # the helper library used for HTML transformations
    attr_accessor :html_helper_lib

    # Create a new ParserBuilder. Allowed options are:
    # * :empty_string_for_nil => false # return the empty string instead of a nil value
    # * :error_on_missing_key => false # raise an error if a specified key or virtual
    #   method does not exist (otherwise nil is returned)
    def initialize(options={})
      @options = options
      
      # rss tags
      @rss_tags = [
        {
          :image     => nil,
          :textinput => nil,
          :skiphours => nil,
          :skipdays  => nil,
          :items     => [{ :rdf_seq => nil }],
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
      @date_tags = [ :pubdate, :lastbuilddate, :published, :updated, :dc_date, 
        :expirationdate ]
  
      # tags that can be used as the default value for a mixed element
      @value_tags = {
        :media_content => :url
      }
      @default_value_tags = [ CONTENT_KEY, :href, :url ]
  
      # methods for selecting the element to return when the singular accessor
      # is called on a tag with multiple values
      @value_selectors = {
        :link => proc do |links|
          links = links.sort do |a,b|
            i1 = DEFAULT_RELS.index(a.rel)
            i2 = DEFAULT_RELS.index(b.rel)
            i1.nil? ? (i2.nil? ? 0 : 1) : (i2.nil? ? -1 : i1 <=> i2)
          end
          links.first
        end
      }
      @default_value_selector = proc do |x|
        x = x.sort do |a,b|
          a.is_a?(String) ? -1 : (b.is_a?(String) ? 1 : 0)
        end
        x.first
      end
  
      # tag/attribute aliases
      @aliases = {
        :items        => :item_array,
        :item_array   => :entry_array,
        :entries      => :entry_array,
        :entry_array  => :item_array,
        :link         => :'link+self'
      }
  
      # transformations
      @html_helper_lib = HPRICOT_HELPER
      @default_transformation = [ :cleanHtml ]
      @transformations = {}
      @transformation_fns = {
        # remove all HTML tags
        :stripHtml => proc do |str| 
          require @html_helper_lib
          FeedMe.html_helper.strip_html(str)
        end,
        
        # clean HTML content using FeedNormalizer's HtmlCleaner class
        :cleanHtml => proc do |str| 
          require @html_helper_lib
          FeedMe.html_helper.clean_html(str)
        end, 
        
        # wrap text at a certain number of characters (respecting word boundaries)
        :wrap => proc do |str, col| 
          str.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/, "\\1\\3\n").strip 
        end,
        
        # truncate text, respecting word boundaries
        :trunc => proc {|str, wordcount| str.trunc(wordcount.to_i) },
        
        # truncate HTML and leave enclosing HTML tags
        :truncHtml => proc do |str, wordcount| 
          require @html_helper_lib
          FeedMe.html_helper.truncate_html(str, wordcount.to_i)
        end,
        
        :regexp => proc do |str, regexp|
          match = Regexp.new(regexp).match(str)
          match.nil? ? nil : match[1]
        end,
        
        # this shouldn't be necessary since all text is automatically
        # unescaped, but some feeds double-escape HTML
        :esc => proc {|str| CGI.unescapeHTML(str) },
        
        # apply an arbitrary function
        :apply => proc {|str, fn, *args| fn.call(str, *args) }
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
        :pubdate        => [ :published, :updated ],
        :lastbuilddate  => [ :updated, :published ],
        :description    => [ :content, :summary ],
        :managingeditor => [ :'author/name', :'contributor/name' ],
        :webmaster      => [ :'author/name', :'contributor/name' ],
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
        :author       => [ :managingeditor, :webmaster ],
        :updated      => [ :lastbuilddate, :pubdate ],
        :published    => [ :pubDate, :lastbuilddate ],
        :icon         => :'image/url',
        :logo         => :'image/url',
        :summary      => :'description_trunc'
      })
    end
    
    # Parse +source+ using a +Parser+ created from this +ParserBuilder+.
    def parse(source)
      Parser.new(self, source, options)
    end
  end

  # This class is used to create strict parsers
  class StrictParserBuilder < ParserBuilder
    attr_accessor :feed_ext_tags, :item_ext_tags, :rels 
    
    def initialize(options={})
      super(options)
      
      # rss tags
      @rss_tags = [
        {
          :image     => [ :url, :title, :link, :width, :height, :description ],
          :textinput => [ :title, :description, :name, :link ],
          :skiphours => [ :hour ],
          :skipdays  => [ :day ],
          :items     => [ 
            {
              :rdf_seq => [ :rdf_li ]
            },
            :rdf_seq 
          ],
         #:item      => @item_tags
        },
        :title, :link, :description,                          # required
        :language, :copyright, :managingeditor, :webmaster,   # optional
        :pubdate, :lastbuilddate, :category, :generator,
        :docs, :cloud, :ttl, :rating,
        :image, :textinput, :skiphours, :skipdays, :item,     # have subtags
        :items
      ]
      @rss_item_tags = [
        {},
        :title, :description,                                 # required
        :link, :author, :category, :comments, :enclosure,     # optional
        :guid, :pubdate, :source, :expirationdate
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
        :link => DEFAULT_RELS
      }
  
      # extensions
      @feed_ext_tags = [ 
        :dc_date, :feedburner_browserfriendly, 
        :itunes_author, :itunes_category
      ]
      @item_ext_tags = [ 
        :dc_date, :dc_subject, :dc_creator, 
        :dc_title, :dc_rights, :dc_publisher, 
        :trackback_ping, :trackback_about,
        :feedburner_origlink, :media_content,
        :content_encoded
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
    
    def initialize(tag_name, parent, builder)
      @fm_tag_name = tag_name
      @fm_parent = parent
      @fm_builder = builder
      @data = {}
    end
    
    def key?(key)
      @data.key?(clean_tag(key))
    end
    
    def keys
      @data.keys
    end
    
    def delete(key)
      @data.delete(clean_tag(key))
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
      @data[clean_tag(key)]
    end
    
    def []=(key, value)
      @data[clean_tag(key)] = value
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
    # returns the first element in the array. If a Proc is passed as the first
    # argument and the array has more than one element, the Proc is used to sort
    # the array before returning the first element.
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
        array = self[array_key]
        elt = if array.size > 1
          if (!args.empty? && args.first.is_a?(Proc))
            args.first.call(array)
          elsif (fm_builder.value_selectors.key?(name))
            fm_builder.value_selectors[name].call(array)
          elsif !fm_builder.default_value_selector.nil?
            fm_builder.default_value_selector.call(array)
          end
        end
        elt || array.first
      elsif name_str[-1,1] == '?'
        !call_virtual_method(name_str[0..-2], args, history).nil? rescue false
      elsif name_str[-1,1] == '!'
        value = call_virtual_method(name_str[0..-2], args, history)
        transform_value(fm_builder.default_transformation, value)
      elsif name_str =~ /(.+)_values/
        call_virtual_method(arrayize($1), args, history).collect do |value|
          _resolve_value value
        end
      elsif name_str =~ /(.+)_value/
        _resolve_value call_virtual_method($1, args, history)
      elsif name_str =~ /(.+)_count/
        call_virtual_method(arrayize($1), args, history).size
      elsif name_str =~ /(.+)_(.+)/ && fm_builder.transformations.key?($2)
        value = call_virtual_method($1, args, history)
        transform_value(fm_builder.transformations[$2], value)
      elsif name_str.include?('/')    # this is only intended to be used internally 
        value = self
        name_str.split('/').each do |p|
          parts = p.split('_')
          name = clean_tag(parts[0])
          new_args = parts.size > 1 ? parts[1..-1] : args
          value = (value.method(name).call(*new_args) rescue 
            value.call_virtual_method(name, new_args, history)) rescue nil
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
          value = (method(name).call(*args) rescue 
            call_virtual_method(name, args, history)) rescue next
          break unless value.nil?
        end
        value
      else
        nil
      end

      raise NameError.new("No such method '#{name}'", name) if result.nil?

      result
    end
    
    # Apply transformations to a tag value. Can either accept a transformation
    # name or an array of transformation function names.
    def transform(tag, trans)
      value = call_virtual_method(tag) or return nil
      transformations = trans.is_a?(String) ? 
        fm_builder.transformations[trans] : trans
      transform_value(transformations, value)
    end
    
    def transform_value(trans_array, value)
      trans_array.each do |t|
        return nil if value.nil?
        
        if t.is_a? String
          value = transform_value(fm_builder.transformations[t], value)
        else
          if t.is_a? Symbol
            t_name = t
            args = []
          elsif t[0].is_a? Array
            raise 'array where symbol expected'
          else
            t_name = t[0]
            args = t[1..-1]
          end
          
          trans = fm_builder.transformation_fns[t_name] or
            raise NoMethodError.new("No such transformation #{t_name}", t_name)
          
          if value.is_a? Array
            value = value.collect do |x| 
              x.nil? ? nil : trans.call(x, *args)
            end.compact
          else  
            value = trans.call(value, *args)
          end
        end
      end
      value
    end
    
    protected 
  
    def clean_tag(tag)
      tag.to_s.downcase.gsub(':','_').intern
    end
  
    # generate a name for the array variable corresponding to a single-value variable
    def arrayize(key)
      clean_tag(key.to_s + '_array')
    end
    
    def unarrayize(key)
      clean_tag(key.to_s.gsub(/_array$/, ''))
    end
    
    private 
    
    def _resolve_value(obj)
      value = obj
      if obj.is_a?(FeedData)
        if fm_builder.value_tags.key? obj.fm_tag_name
          value = obj.call_virtual_method(fm_builder.value_tags[obj.fm_tag_name])
        else
          fm_builder.default_value_tags.each do |tag|
            value = obj.call_virtual_method(tag) rescue next
            break unless value.nil?
          end
        end
      end
      value
    end
  end

  class Parser < FeedData
    attr_reader :fm_source, :fm_options, :fm_type, :fm_tags, :fm_parsed, :fm_unparsed
  
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
      @fm_type == FeedMe::ATOM ? 'feed' : 'channel'
    end
  
    def fm_prefix
      fm_type.to_s.downcase
    end
  
    private
  
    def parse
      # RSS = everything between channel tags + everthing between </channel> and 
      # </rdf> if this is an RDF document. Do a simpler match to begin with
      # since the more complex regexp will hang on a large and invalid document.
      if @fm_source =~ %r{<(?:.*?:)?channel.+</(?:.*?:)?channel}mi && 
         @fm_source =~ %r{<(?:.*?:)?(rss|rdf)(.*?)>.*?<(?:.*?:)?channel(.*?)>(.+)</(?:.*?:)?channel>(.*)</(?:.*?:)?(?:rss|rdf)>}mi
        @fm_type = $1.upcase.to_s
        @fm_tags = fm_builder.all_rss_tags
        attrs = parse_attributes($1, $2 + $3)
        attrs[:version] ||= '1.0';
        parse_content(self, attrs, $4, @fm_tags)

        # for RDF documents, replace references with actual items
        unless nil_or_empty?($5)
          refs = FeedData.new(nil, nil, fm_builder)
          parse_content(refs, {}, $5, @fm_tags)
          dereference_rdf_tags(:items_array, :item_array, refs) {|a| a.first[:rdf_seq_array].first[:rdf_li_array] }
          [:image_array, :textinput_array].each {|tag| dereference_rdf_tags(tag, tag, refs) }
        end
      # Atom = everthing between feed tags
      elsif @fm_source =~ %r{<(?:.*?:)?feed(.*?)>(.+)</(?:.*?:)?feed>}mi
        @fm_type = FeedMe::ATOM
        @fm_tags = fm_builder.all_atom_tags
        parse_content(self, parse_attributes($1), $2, @fm_tags)
      else
        raise FeedMeError, "Poorly formatted feed"
      end
    end

    # References within the <channel> element are replaced by the actual 
    def dereference_rdf_tags(rdf_tag, rss_tag, refs)
      if self.key?(rdf_tag)
        src_items = self.delete(rdf_tag)
        src_items = yield(src_items) if block_given?
        ref_items = refs[rss_tag]
        unless src_items.empty? || ref_items.empty?
          self[rss_tag] = src_items.collect do |src_item|
            next unless src_item.key?(:rdf_resource)
            uri = src_item[:rdf_resource]
            ref_items.each do |ref_item|
              next unless ref_item.key?(:rdf_about)
              if (ref_item[:rdf_about].eql?(uri))
                ref_item[:rdf_resource] = uri
                break ref_item
              end
            end
          end
        end
      end
    end
    
    def parse_content(parent, attrs, content, tags)
      # add attributes to parent
      attrs.each_pair {|key, value| parent[key] = unescape(value) }
      return if content.nil?

      # split the content into elements
      elements = {}
      # TODO: this will break if a namespace is used that is not rss: or atom:    
      content.scan( %r{(<([\w:]+)(.*?)(?:/>|>(.*?)</\2>))}mi ) do |match|
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
      
      # the first item in a tag array may be a hash that defines tags that have subtags
      sub_tags = tags[0] if !nil_or_empty?(tags) && tags[0].is_a?(Hash)
      first_tag = sub_tags.nil? || tags.size == 1 ? 0 : 1
      # if this is a promiscuous parser, tag names will depend on the elements found in the feed
      tags = elements.keys if (sub_tags.nil? ? nil_or_empty?(tags) : first_tag == 0)
      
      # iterate over all tags (some or all of which may not be present)
      tags[first_tag..-1].each do |tag|
        key = clean_tag(tag)
        element_array = elements.delete(tag) or next
        @fm_parsed << key

        element_array.each do |elt|
          elt_attrs = elt[0]
          elt_content = elt[1]
          rels = fm_builder.rels[key] if fm_builder.respond_to?(:rels)
          
          # if a list of accepted rels is specified, only parse this tag
          # if its rel attribute is inlcuded in the list
          next unless rels.nil? || elt_attrs.nil? || !elt_attrs.rel? || rels.include?(elt_attrs.rel)
          
          if !sub_tags.nil? && sub_tags.key?(key)
            new_parent = FeedData.new(key, parent, fm_builder)
            add_tag(parent, key, new_parent)
            parse_content(new_parent, elt_attrs, elt_content, sub_tags[key])
          else
            add_tag(parent, key, clean_content(key, elt_attrs, elt_content, parent))
          end
        end
      end

      @fm_unparsed += elements.keys
      @fm_parsed.uniq!
      @fm_unparsed.uniq!
    end

    def add_tag(hash, key, value)
      array_var = arrayize(key)
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
        hash = FeedData.new(tag, parent, fm_builder)
        attrs.each_pair {|key, value| hash[key] = unescape(value) }
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
        array = a.scan(/([\w:]+)=['"]?([^'"]+)/)
        # unescape values
        array = array.collect {|key, value| [clean_tag(key), unescape(value)]}
        hash.merge! Hash[*array.flatten]
      end
      return hash
    end
  
    def unescape(content)
      cdata = content.match(%r{<!\[CDATA\[(.*)\]\]>}mi)
      if cdata
        # CDATA-escaped content is not encoded
        content = cdata[1]
      else
        # unescape
        content = CGI.unescapeHTML(content)
        # further unescape any URL query strings
        query = content.match(/^(http:.*\?)(.*)$/)
        content = query[1] + CGI.unescape(query[2]) if query
      end
      
      return content
    end
    
    def nil_or_empty?(obj)
      obj.nil? || obj.empty? || (obj.is_a?(String) && obj.strip.empty?)
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