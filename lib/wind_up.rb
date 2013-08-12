require 'celluloid'
require 'wind_up/exceptions'
require 'wind_up/signals'
require 'wind_up/new_work_publisher'
require 'wind_up/new_work_subscriber'
require 'wind_up/queue_proxy'
require 'wind_up/queue_manager'
require 'wind_up/version'

module WindUp
  def self.logger
    Celluloid.logger
  end

  def self.logger=(logger)
    Celluloid.logger = logger
  end
end

require 'wind_up/railtie' if defined?(::Rails)
