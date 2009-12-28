# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{feedme}
  s.version = "0.8"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Didion"]
  s.date = %q{2009-12-28}
  s.description = %q{A simple, flexible, and extensible RSS and Atom parser for Ruby. Based on the popular SimpleRSS library, but with many nice extra features.}
  s.email = ["code@didion.net"]
  s.extra_rdoc_files = [
    "History.txt",
     "Manifest.txt",
     "README.txt"
  ]
  s.files = [
    "History.txt",
     "Manifest.txt",
     "README.txt",
     "Rakefile",
     "examples/rocketboom.rb",
     "examples/rocketboom.rss",
     "lib/feedme.rb",
     "lib/hpricot-util.rb",
     "lib/html-cleaner.rb",
     "lib/nokogiri-util.rb",
     "lib/util.rb",
     "test/test_helper.rb"
  ]
  s.homepage = %q{http://wiki.github.com/jdidion/feedme}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{feedme}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{A simple, flexible, and extensible RSS and Atom parser for Ruby}
  s.test_files = [
    "test/test_helper.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

