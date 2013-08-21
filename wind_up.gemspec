# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wind_up/version'

Gem::Specification.new do |gem|
  gem.name          = "wind_up"
  gem.version       = WindUp::VERSION
  gem.authors       = ["Ryan Chan"]
  gem.email         = ["ryan@ryanlchan.com"]
  gem.summary       = %q{Super simple background processing}
  gem.description   = %q{WindUp enables simple background processing using Celluloid Actors}
  gem.homepage      = "https://github.com/ryanlchan/wind_up"

  gem.files         = Dir['README.md', 'lib/**/*', 'spec/**/*']
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency "rspec"
  gem.add_development_dependency "rake"

  gem.add_dependency "wind_up_queue", "~> 0.0.1"
end
