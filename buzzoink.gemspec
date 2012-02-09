$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "buzzoink/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "buzzoink"
  s.version     = Buzzoink::VERSION
  s.authors     = ["Chris Hagar", "Bob Briski"]
  s.email       = ["chagar@raybeam.com", "bbriski@raybeam.com"]
  s.homepage    = "TODO"
  s.summary     = "Start hive or pig processes in EMR"
  s.description = "TODO: Description of Buzzoink."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]

  s.add_dependency "activesupport", "~> 3.0"
  s.add_dependency "addressable", "~> 2.2"
  s.add_dependency "andand", "~> 1.3"
  s.add_dependency "fog", "~> 1.1.2"
  s.add_dependency "sys-proctable"

  s.add_development_dependency "sqlite3"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "webmock"
  s.add_development_dependency "fabrication"
  s.add_development_dependency "vcr"
end