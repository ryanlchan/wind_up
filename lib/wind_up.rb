require 'celluloid'
require 'sucker_punch'
require 'wind_up/exceptions'
require 'wind_up/worker'
require 'wind_up/api'
require 'wind_up/store/in_memory'
require 'wind_up/store/redis'
require 'wind_up/queue'
require 'wind_up/version'

module WindUp
  def self.config(&block)
    instance_eval &block
  end

  # Define a new queue
  def self.queue(options = {}, &block)
    raise MissingQueueName unless options[:name]
    raise MissingWorkerName unless options[:worker] || options[:pool]

    name = options.fetch(:name)

    # Check existance
    existing = Queue[name]
    if existing && existing.alive?
      WindUp.logger.warn "Overwriting Celluloid actor registered at #{name}"
      existing.terminate
    end

    q = Queue.supervise_as name, options, &block
    Queue[name].async.feed_pool
  end

  def self.logger
    Celluloid.logger
  end

  def self.logger=(logger)
    Celluloid.logger = logger
  end
end

require 'wind_up/railtie' if defined?(::Rails)
