require 'celluloid'
require 'wind_up/exceptions'
require 'wind_up/calls'
require 'wind_up/routers'
require 'wind_up/queue_proxy'
require 'wind_up/queue_manager'
require 'wind_up/version'
require 'wind_up/celluloid_ext'

module WindUp
  def self.logger
    Celluloid.logger
  end

  def self.logger=(logger)
    Celluloid.logger = logger
  end
end

require 'wind_up/railtie' if defined?(::Rails)
