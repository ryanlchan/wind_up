# Extend Celluloid with the ability to use Klass.queue
module WindUp
  module CelluloidExts
    def queue(options = {})
      WindUp::QueueManager.new(self, options).queue
    end
  end
end

Celluloid::ClassMethods.send :include, WindUp::CelluloidExts
