# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wind_up/version'

Gem::Specification.new do |gem|
  gem.name          = "wind_up"
  gem.version       = WindUp::VERSION
  gem.authors       = ["Ryan Chan"]
  gem.email         = ["ryan@ryanlchan.com"]
  gem.description   = %q{Simple multiplexing queueing library for sucker_punch}
  gem.summary       = %q{wind_up makes Sidekiq level queuing available to sucker_punch}
  gem.homepage      = "https://github.com/ryanlchan/wind_up"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency "rspec"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "redis"
  gem.add_development_dependency "connection_pool"

  gem.add_dependency "celluloid", "~> 0.14.1"
  gem.add_dependency "sucker_punch", "~> 0.5.1"
  gem.add_dependency "multi_json", "~> 1.7.7"
end
