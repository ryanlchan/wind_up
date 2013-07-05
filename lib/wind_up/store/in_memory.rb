module WindUp
  module Store
    class InMemory
      def initialize(name, options = {})
        @name = name
        @queues = {}
      end

      def push(args, priority_level: nil)
        priority_level ||= :default

        @queues[priority_level] ||= []
        @queues[priority_level] << args
      end
      alias_method :<<, :push

      def pop(levels = nil)
        levels ||= @queues.keys
        levels = [levels] unless levels.respond_to? :inject
        levels.inject(nil) { |memo, level| memo || (@queues[level] && @queues[level].shift) }
      end
      alias_method :fetch, :pop

      # Number of jobs in the queues
      # @return [Hash] a hash of queue names and sizes
      def size
        Hash[@queues.collect{ |level, list| [level, list.size] }]
      end

      def reset!
        @queues = {}
      end
    end
  end
end
