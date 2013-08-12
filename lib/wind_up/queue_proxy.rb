# A proxy object which forwards async/future calls synchronously
#
# We want QueueManager to handle all logic for forwarding calls, including
# #async and #future, but ActorProxy globs those as Celluloid methods.
# QueueProxy simply forwards them to the QueueManager to deal with.
module WindUp
  class QueueProxy < Celluloid::ActorProxy
    def async(method_name = nil, *args, &block)
      method_missing :async, method_name, *args, &block
    end

    def future(method_name = nil, *args, &block)
      method_missing :future, method_name, *args, &block
    end
  end
end
