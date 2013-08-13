# Manages a queue of workers
# Accumulates/stores messages and supervises a group of workers
module WindUp
  class QueueManager
    include Celluloid
    attr_reader :size

    trap_exit :restart_actor
    proxy_class WindUp::QueueProxy

    def initialize(worker_class, options = {})
      @size = options[:size] || [Celluloid.cores, 2].max

      @worker_class = worker_class
      @args = options[:args] ? Array(options[:args]) : []

      @master_mailbox = Celluloid::Mailbox.new
      @sync_proxy     = Celluloid::SyncProxy.new(@master_mailbox, @worker_class)
      @async_proxy    = Celluloid::AsyncProxy.new(@master_mailbox, @worker_class)
      @future_proxy   = Celluloid::FutureProxy.new(@master_mailbox, @worker_class)

      @registry = Celluloid::Registry.root
      @group    = []
      resize_group
    end

    # Terminate our supervised group on finalization
    finalizer :__shutdown__
    def __shutdown__
      group.reverse_each(&:terminate)
    end

    ##################
    # Method Capture #
    ##################
    # These methods capture and forward methods called on the QueueManager to
    # the Supervised workers

    # Obtain an async proxy or explicitly invoke a named async method
    def async(method_name = nil, *args, &block)
      if method_name
        @async_proxy.method_missing method_name, *args, &block
      else
        @async_proxy
      end
    end

    # Obtain a future proxy or explicitly invoke a named future method
    def future(method_name = nil, *args, &block)
      if method_name
        @future_proxy.method_missing method_name, *args, &block
      else
        @future_proxy
      end
    end

    def method_missing(meth, *args, &block)
      @sync_proxy.method_missing meth, *args, &block
    end
    alias_method :sync, :method_missing

    def respond_to?(method, include_private = false)
      super || @worker_class.instance_methods.include?(method.to_sym)
    end

    def name
      method_missing :name
    end

    def is_a?(klass)
      method_missing :is_a?, klass
    end

    def kind_of?(klass)
      method_missing :kind_of?, klass
    end

    def send(meth, *args, &block)
      # Dirty, dirty hack here to intercept the exit event signals instead of
      # sending them to the pool.
      # TODO: Log this issue with Celluloid
      if meth == :restart_actor
        super
      else
        method_missing :send, meth, *args, &block
      end
    end

    def methods(include_ancestors = true)
      method_missing :methods, include_ancestors
    end

    ###########
    # Helpers #
    ###########

    # Resize this queue's worker group
    # NOTE: Using this to down-size your queue CAN truncate ongoing work!
    #   Workers which are waiting on blocks/sleeping will receive a termination
    #   request prematurely!
    # @param num [Integer] Number of workers to use
    def size=(num)
      @size = num
      resize_group
    end

    # Return the size of the queue backlog
    # @return [Integer] the number of messages queueing
    def backlog
      @master_mailbox.size
    end

    def inspect
      "<WindUp::QueueManager @size=#{@size} @worker_class=#{@worker_class} @backlog=#{backlog}>"
    end

    ####################
    # Group Management #
    ####################

    # Restart a crashed actor
    def restart_actor(actor, reason)
      member = group.find do |_member|
        _member.actor == actor
      end
      raise "A group member went missing. This shouldn't be!" unless member

      member.restart(reason)
    end

    private
    def group
      @group ||= []
    end

    # Resize the worker group in this queue
    # You should probably be using #size=
    # @param target [Integer] the targeted number of workers to grow to
    def resize_group(target = size)
      delta = target - group.size
      if delta == 0
        # *Twiddle thumbs*
        return
      elsif delta > 0
        # Increase pool size
        delta.times do
          worker = Celluloid::SupervisionGroup::Member.new @registry, @worker_class, :args => @args
          group << worker
          @master_mailbox.add_subscriber(worker.actor.mailbox)
        end
      else
        # Truncate pool
        delta.abs.times { @master_mailbox << Celluloid::TerminationRequest.new }
      end
    end
  end
end
