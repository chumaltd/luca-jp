lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'luca/jp/version'

Gem::Specification.new do |spec|
  spec.name          = 'luca-jp'
  spec.version       = Luca::Jp::VERSION
  spec.license       = 'GPL'
  spec.authors       = ['Chuma Takahiro']
  spec.email         = ['co.chuma@gmail.com']

  spec.required_ruby_version = '>= 2.7.0'

  spec.summary       = %q{JP tax extension for Luca}
  spec.description   =<<~DESC
   JP tax extension for Luca
  DESC
  spec.homepage      = 'https://github.com/chumaltd/luca-jp'

  if spec.respond_to?(:metadata)
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/chumaltd/luca-jp'
    spec.metadata['changelog_uri'] = 'https://github.com/chumaltd/luca-jp/CHANGELOG.md'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files         = Dir["LICENSE", "exe/**/*", "lib/**/{*,.[a-z]*}"]
  spec.bindir        = 'exe'
  spec.executables   = ['luca-jp']
  spec.require_paths = ['lib']

  spec.add_dependency 'lucabook', '>= 0.4'
  spec.add_dependency 'lucasalary', '>= 0.1.26'
  spec.add_dependency 'jp_nationaltax', '>= 0.1.3'

  spec.add_development_dependency 'bundler', '~> 2.3'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '>= 12.3.3'
end
