begin
  require 'pry'
rescue LoadError
end

require 'celluloid'
require 'wind_up_queue'
require 'wind_up'

Celluloid.shutdown; Celluloid.boot

LOGGING_MUTEX = Mutex.new
def mute_celluloid_logging
  LOGGING_MUTEX.synchronize do
    # Temporarily mute celluloid logger
    Celluloid.logger.level = Logger::FATAL
    yield if block_given?
    # Allow any async messages to process before completing
    sleep 0.01
    # Restore celluloid logger
    Celluloid.logger.level = Logger::DEBUG
  end
end
