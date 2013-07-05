# TODO: Reimplement the testing API from SuckerPunch in WindUp
# module WindUp
#   class << self
#     attr_accessor :queues

#     def reset!
#       self.queues = {}
#     end
#   end

#   WindUp.reset!

#   class Queue
#     attr_reader :name

#     def initialize(name)
#       @name = name
#       WindUp.queues[name] ||= []
#     end

#     def self.[](name)
#       new(name)
#     end

#     def register(klass, size)
#       nil
#     end

#     def workers
#       raise "Not implemented"
#     end

#     def jobs
#       WindUp.queues[@name]
#     end

#     def async
#       self
#     end

#     def method_missing(name, *args, &block)
#       WindUp.queues[@name] << { method: name, args: Array(args) }
#     end
#   end
# end
