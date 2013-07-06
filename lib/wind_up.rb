require 'celluloid'
require 'wind_up/exceptions'
require 'wind_up/worker'
require 'wind_up/api'
require 'wind_up/store/in_memory'
require 'wind_up/store/redis'
require 'wind_up/singleton'
require 'wind_up/queue'
require 'wind_up/version'
require 'wind_up/workers/handler_worker'

module WindUp
  def self.logger
    Celluloid.logger
  end

  def self.logger=(logger)
    Celluloid.logger = logger
  end
end

require 'wind_up/railtie' if defined?(::Rails)
