# Manages a queue of workers
# Accumulates/stores messages and supervises a group of workers
# WindUp `Queues` are almost drop-in replacements for Celluloid pools.
#
# ```ruby
# q = AnyCelluloidClass.queue size: 3 # size defaults to number of cores
# q.any_method                # perform synchronously
# q.async.long_running_method # perform asynchronously
# q.future.i_want_this_back   # perform as a future
# ```
#
# `Queues` use two separate proxies to control `Queue` commands vs
# `QueueManager` commands.
# ```ruby
# # .queue returns the proxy for the queue (i.e. workers)
# q = AnyCelluloidClass.queue # => WindUp::QueueProxy(AnyCelluloidClass)
#
# # Get the proxy for the manager from the QueueProxy
# q.__manager__ # => Celluloid::ActorProxy(WindUp::QueueManager)
#
# # Return to the queue from the manager
# q.__manager__.queue # WindUp::QueueProxy(AnyCelluloidClass)
# ```
#
# You may store these `Queue` object in the registry as any actor
# ```ruby
# Celluloid::Actor[:queue] = q
# ```
module WindUp
  class QueueManager
    include Celluloid
    attr_reader :size, :master_mailbox, :worker_class

    trap_exit :restart_actor

    # Don't use QueueManager.new, use Klass.queue instead
    def initialize(worker_class, options = {})
      @size = options[:size] || [Celluloid.cores, 2].max

      @worker_class = worker_class
      @master_mailbox = PublisherMailbox.new
      @args = options[:args] ? Array(options[:args]) : []


      @registry = Celluloid::Registry.root
      @group    = []
      resize_group
    end

    # Terminate our supervised group on finalization
    finalizer :__shutdown__
    def __shutdown__
      @master_mailbox.shutdown
      group.reverse_each(&:terminate)
    end

    ###########
    # Helpers #
    ###########

    # Access the Queue's proxy
    def queue
      WindUp::QueueProxy.new Actor.current
    end

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
      "<Celluloid::ActorProxy(#{self.class}) @size=#{@size} @worker_class=#{@worker_class} @backlog=#{backlog}>"
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

      if reason
        member.restart(reason)
      else
        # Remove from group on clean shutdown
        group.delete_if do |_member|
          _member.actor == actor
        end
      end
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
