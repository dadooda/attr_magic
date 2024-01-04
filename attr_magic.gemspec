
require_relative "lib/attr_magic/version"

Gem::Specification.new do |s|
  s.name = "attr_magic"
  s.summary = "The tools to ease lazy attribute implementation"
  s.version = AttrMagic::VERSION

  s.authors = ["Alex Fortuna"]
  s.email = ["fortunadze@gmail.com"]
  s.homepage = "https://github.com/dadooda/attr_magic"
  s.license = "MIT"

  s.files = `git ls-files`.split("\n")
  s.require_paths = ["lib"]
  s.test_files = `git ls-files -- {spec}/*`.split("\n")
end
