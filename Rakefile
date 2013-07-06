require "bundler/gem_tasks"
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new('spec')

# If you want to make this the default task
task :default => :spec
task :test => :spec

task :console do
  exec "irb -r wind_up -I ./lib"
end

task :rspec do
  exec "rspec -f doc --color"
end
