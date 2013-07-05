begin
  require 'pry'
rescue LoadError
end

require 'wind_up'
require 'connection_pool'
require 'redis'

Celluloid.shutdown; Celluloid.boot
