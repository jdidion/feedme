= feedme

* http://wiki.github.com/jdidion/feedme

== DESCRIPTION:

A simple, flexible, and extensible RSS and Atom parser for Ruby. Based on the popular SimpleRSS library, but with many nice extra features.

== FEATURES/PROBLEMS:

* Parse RSS 0.91, 0.92, 1.0, and 2.0
* Parse Atom
* Parse all tags by default, or choose the tags you want to parse
* Access all attributes and content as if they were methods
* Access all values of tags that can appear multiple times
* Delicious syntactic sugar that makes it simple to get the data you want

=== SYNOPSIS:

The API is similar to SimpleRSS:

    require 'rubygems'
    require 'feedme'
    require 'open-uri'

    rss = FeedMe.parse open('http://slashdot.org/index.rdf')
    rss.version # => 1.0
    rss.channel.title # => "Slashdot"
    rss.channel.link # => "http://slashdot.org/"
    rss.items.first.link # => "http://books.slashdot.org/article.pl?sid=05/08/29/1319236&from=rss"

But since the parser can read Atom feeds as easily as RSS feeds, there are optional aliases that allow more atom like reading:

    rss.feed.title # => "Slashdot"
    rss.feed.link # => "http://slashdot.org/"
    rss.entries.first.link # => "http://books.slashdot.org/article.pl?sid=05/08/29/1319236&from=rss"

Under the covers, all content is stored in arrays. This means that you can access all content for a tag that appears multiple times (i.e. category):
    
    rss.items.first.category_array  # => ["News for Nerds", "Technology"]
    rss.items.first.category # => "News for Nerds"
    
You also have access to all the attributes as well as tag values:

    rss.items.first.guid.isPermaLink # => "true"
    rss.items.first.guid.content     # => http://books.slashdot.org/article.pl?sid=05/08/29/1319236

FeedMe also adds some syntactic sugar that makes it easy to get the information you want:

    rss.items.first.category? # => true
    rss.items.first.category_count # => 2
    rss.items.first.guid_content # => http://books.slashdot.org/article.pl?sid=05/08/29/1319236

There are two different parsers that you can use, depending on your needs. The default parser is "promiscuous," meaning that it parses all tags. There is also a strict parser that only parses tags specified in a list. Here is how you create the different types of parsers:
    
    FeedMe.parse(source) # parse using the default (promiscuous) parser
    FeedMe::ParserBuilder.new.parse(source) # equivalent to the previous line
    FeedMe::StrictParserBuilder.new.parse(source) # only parse certain tags

The strict parser can be extended by adding new tags to parse:

    builder = FeedMe::StrictParserBuilder.new
    builder.rss_tags << :some_new_tag
    builder.rss_item_tags << :'item+myrel' # parse an item that has a custom rel type
    builder.item_ext_tags << :'feedburner:origLink' # parse an extension tag - one that has a specific 
                                                    # namespace
    
Either parser can be extended by adding aliases to existing tags:

    builder.aliases[:updated] => :pubDate  # now you can always access the updated date using :updated, 
                                           # regardless of whether it's an RSS or Atom feed

Another bit of syntactic sugar is the "bang mod." These are modifications that can be applied to feed content by adding '!' to the tag name. The default bang mod is to strip HTML tags from the content.

    rss.entry.content # => <div>Some great stuff</div>
    rss.entry.content! # => Some great stuff
    
You can create your own bang mods. The following is an example of a bang mod that takes an argument. The first line is how bang mods are added, and the second line tells the builder to actually apply this bang mod when the '!' suffix is used. Note that bang mod names may only contain alphanumeric characters. Argument values are specified at the end separated by underscores.

    # wrap content at a specified number of columns
    builder.bang_mod_fns[:wrap] => proc {|str, col| 
        str.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/, "\\1\\3\n").strip 
    }
    builder.bang_mods << :wrap_80

In order to prevent clashes between tag/attribute names and the parser class' instance variables, all instance variables are prefixed with 'fm_'. They are:
    
    fm_source   # the original, unparsed source 
    fm_options  # the options passed to the parser constructor
    fm_type     # the feed type
    fm_tags     # the tags the parser looks for in the source
    fm_parsed   # the list of tags the parser actually found
    fm_unparsed # the list of tags that appeared in the feed but were not parsed (useful for debugging)

Additionally, there are several variables that are available at every level of the parse tree:

    fm_builder  # the ParserBuilder that created the parser
    fm_parent   # the container of the current level of the parse tree
    fm_tag_name # the name of the rss/atom tag whose content is contained in this level of the tree

=== A word on RSS/Atom Versions

RSS has undergone much revision since Netscape 0.90 was released in 1999. The current accepted specification is maintained by the RSS Advisory board (http://www.rssboard.org/rss-specification). The current version (as of this writing) is 2.0.11, although the actual schema has not changed since 2.0.1.

Atom is an IETF standard (http://www.w3.org/2005/Atom) and so far there is a single version of the specification (commonly referred to as 1.0). 

FeedMe does its best to support RSS and Atom versions currently in use. It specifically does *NOT* support any Netscape version of RSS.

Due to various incompatibilities between different RSS versions, it is strongly recommended that you examine the version attribute of the feed (as shown in the Usage section). Mark Pilgrim has an excellent article on RSS version incompatibility: http://diveintomark.org/archives/2004/02/04/incompatible-rss.

== INSTALL:

* gem install feedme
* http://rubyforge.org/projects/feedme

== LICENSE:

This work is licensed under the Creative Commons Attribution 3.0 United States License. To view a copy of this license, visit http://creativecommons.org/licenses/by/3.0/us/ or send a letter to Creative Commons, 171 Second Street, Suite 300, San Francisco, California, 94105, USA.
