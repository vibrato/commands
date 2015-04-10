#$:.push File.expand_path("../lib", __FILE__)
# Maintain your gem's version:
#require "commands/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "commands"
  s.version     = "0.0.1"
  s.authors     = ["James Martelletti"]
  s.email       = ["james@vibrato.com.au"]
  s.homepage    = "https://vibrato.com.au"
  s.summary     = "Commands"
  s.description = "Commands"

  s.files = Dir["{app,config,db,lib}/**/*", "Rakefile", "Readme.md"]
  s.test_files = Dir["test/**/*"]
  s.executables << 'commands'

  s.add_dependency "aws-sdk", "2.0.6.pre"
  s.add_dependency "sshkit"
  s.add_dependency "sshkey"
end
