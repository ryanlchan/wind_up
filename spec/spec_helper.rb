begin
  require 'pry'
rescue LoadError
end

require 'celluloid'
require 'wind_up'

Celluloid.shutdown; Celluloid.boot

def mute_celluloid_logging
  # Temporarily mute celluloid logger
  Celluloid.logger.level = Logger::FATAL
  yield if block_given?
  # Restore celluloid logger
  Celluloid.logger.level = Logger::DEBUG
end
