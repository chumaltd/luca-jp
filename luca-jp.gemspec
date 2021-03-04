lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'luca/jp/version'

Gem::Specification.new do |spec|
  spec.name          = 'luca-jp'
  spec.version       = Luca::Jp::VERSION
  spec.license       = 'GPL'
  spec.authors       = ['Chuma Takahiro']
  spec.email         = ['co.chuma@gmail.com']

  spec.required_ruby_version = '>= 2.6.0'

  spec.summary       = %q{JP tax extension for Luca}
  spec.description   =<<~DESC
   JP tax extension for Luca
  DESC
  spec.homepage      = 'https://github.com/chumaltd/luca-jp/tree/main'

  if spec.respond_to?(:metadata)
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/chumaltd/luca-jp/tree/main'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files         = Dir["LICENSE", "exe/**/*", "lib/**/{*,.[a-z]*}"]
  spec.bindir        = 'exe'
  spec.executables   = ['luca-jp']
  spec.require_paths = ['lib']

  spec.add_dependency 'lucabook'

  spec.add_development_dependency 'bundler', '>= 1.17'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '>= 12.3.3'
end
