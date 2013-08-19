# A proxy object which sends calls to a Queue mailbox
module WindUp
  class QueueProxy < Celluloid::ActorProxy
     def initialize(manager)
      @mailbox       = manager.router
      @klass         = manager.worker_class.to_s
      @sync_proxy    = ::Celluloid::SyncProxy.new(@mailbox, @klass)
      @async_proxy   = ::Celluloid::AsyncProxy.new(@mailbox, @klass)
      @future_proxy  = ::Celluloid::FutureProxy.new(@mailbox, @klass)

      @manager_proxy = manager
    end

    # Escape route to access the QueueManager actor from the QueueProxy
    def __manager__
      @manager_proxy
    end

    # Reroute terminate to the queue manager
    def terminate
      __manager__.terminate
    end

    def inspect
      orig = super
      orig.sub("Celluloid::ActorProxy", "WindUp::QueueProxy")
    end
  end
end
