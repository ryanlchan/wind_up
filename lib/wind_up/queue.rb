# A Singleton queuing interface
module WindUp
  module Queue
    # Initialize Queue methods on inclusion in a class
    def self.included(base)
      base.send(:include, Worker)
      base.send(:include, Singleton)
      base.extend(ClassMethods)
    end

    # Dynamically create Queue classes using a block.
    # Usage:
    #   WindUp::Queue.new "NewQueue" { workers(5); store(:redis) }
    def self.new(name, &block)
      c = Class.new

      Object.const_set(name, c)

      c.send(:include, WindUp::Queue)

      if block_given?
        c.instance_eval &block
      else
        c.instance_eval { worker_class WindUp::Workers::HandlerWorker }
      end
      return c
    end


    module ClassMethods
      # Delegate class methods down to the Instance
      def method_missing(meth, *args, &block)
        if instance.respond_to? meth
          instance.send(meth, *args, &block)
        else
          super
        end
      end

      # Intentionally skip Celluloid Pooling, going direct to instance
      def pool(*args)
        instance.pool(*args)
      end
    end

    ##################
    # Initialization #
    ##################
    # Initialize a new Queue
    def initialize
      register
      after(0) { feed_pool }
    end

    # Create or register the pool of workers
    # Thread-safety comes from Singleton; only one instance should exist
    # @return [Celluloid::Pool] the pool of workers
    def create_pool(overwrite = false)
      if find_pool.nil? || overwrite
        raise MissingWorkerName unless worker_class
        terminate_pool
        Celluloid::Actor[pool_name] = worker_class.pool( size: workers )
      end
      find_pool
    end

    def terminate_pool
      find_pool.terminate if find_pool && find_pool.respond_to?(:terminate)
    end

    # Register this queue with the WindUp API
    def register
      WindUp::API::Queues.register name
    end

    #################
    # Configuration #
    #################
    # Set a persistance strategy for this option
    # @note Redis store will attempt to connect using :connection, :url, ENV vars, then fallback to localhost
    # @param store_name [:redis, :memory] :store the type of store to use
    # @param options [Hash] options for this store
    # @option options [Object] :connection the connection to use for the store
    # @option options [String] :url the Redis connection url
    # @option options [String] :size the connection pool size [Default = 3]
    # @option options [String] :timeout the connection pool timeout [Default = 5]
    # @return [WindUp::Store] the storage strategy
    def store(store_name = :memory, options = {})
      s = case store_name
          when :redis, 'redis'
            Store::Redis
          else
            Store::InMemory
          end
      @store ||= s.new( name, options )
    end

    # Create a new priority level for this queue
    # @param priority_level_name [String] the name of the priority level
    # @param options [Hash] any options for configuring this level
    # @option options [Integer] :weight when given, this level will be drawn N
    #     times as frequently as non-weighted levels
    # @option options [Boolean] :default set this level to be the default
    #     level for adding jobs
    def priority_level(priority_level_name, options = {})
      weighted_priority_levels.delete(priority_level_name)
      [options[:weight].to_i, 1].max.times { weighted_priority_levels << priority_level_name }
      priority_levels << priority_level_name
      @default_priority_level = priority_level_name if options[:default]
    end

    # Return the priority levels for this Queue
    # @return [Array] an array of priority levels, in order of definition
    def priority_levels
      @priority_levels ||= Set.new
    end

    def weighted_priority_levels
      @weighted_priority_levels ||= []
    end

    # The default priority level to push into
    def default_priority_level
      @default_priority_level ||= priority_levels.first
    end

    # Define the number of workers to use for this queue
    # @param num [Integer] the number of workers to use
    def workers(num = nil)
      if num.nil?
        @workers = 1 if find_pool.respond_to?(:async) # Pool is a single Celluloid cell
        @workers = find_pool.size if find_pool.respond_to?(:size) # Pool has multiple cells
        @workers ||= ::Celluloid.cores # Pool doesn't exist
      else
        @workers = num
        create_pool(true)
      end
    end

    # Define what class to use as a worker for this queue
    # @param klass [Class] the class to use as a worker
    def worker_class(klass = nil)
      if klass.nil?
        @worker_class
      else
        recreate = @worker.nil?
        @worker_class = klass
        create_pool(true) unless recreate
      end
    end

    # Force this Queue to look for/create a pool under a specific name
    # @param pool_name [String] the pool name, as discoverable through Celluloid's registry
    def pool_name(pname = nil)
      if pname.nil?
        @pool_name ||= "#{self.class.name}:pool"
      else
        terminate_pool if @pool_name
        @pool_name = pname
        create_pool
      end
    end

    # Set this queue as strictly ordered
    # Strictly ordered queues draw down priority levels in order of
    # definition; first defined level is always drawn down before second,
    # etc.
    # @param set [Boolean] set this queue as strict
    def strict(set = nil)
      if set.nil?
        @set ||= false
      else
        @strict = set
      end
    end

    ###########
    # Queuing #
    ###########
    # Push a message onto the queue
    # @param args [Object] the object to pass to the workers
    # @param opts [Hash] the options to push with
    # @option opts [String] :priority_level the priority level to push this message to
    def push(args, opts = {})
      opts = {priority_level: default_priority_level}.merge(opts)
      store.push args, opts
      return args
    end
    alias_method :<<, :push

    # Pop a message off the queue
    # @param target [String, Array] the priority levels to pop, in order ot priority
    # @return [Object] the message passed into the queue
    def pop(levels = queues_for_fetch)
      store.pop levels
    end
    alias_method :fetch, :pop

    # Return the worker pool for this Queue
    def pool
      @pool ||= (find_pool || create_pool)
    end

    # Continually fetches new work for the pool whenever a worker is available
    # We use a self-referential schedule to avoid blocking the worker, which
    # allows us to do things like push new jobs and such.
    # If worker isn't fully configured yet, we poll every 5 seconds until it is
    def feed_pool
      begin
        # Ensure that we're properly configured
        if !ready?
          pause
          after(5) { unpause }

        # Ensure that this queue is running and that there is work to be done
        elsif paused? || !available?

        # Parse out the work
        else
          work = fetch
          if work
            WindUp.logger.debug "(IW: #{idle_workers} BW: #{busy_workers}) Proessing new job: #{work}"
            pool.async.perform(work)
          end
          after(0) { feed_pool }
        end
      rescue Celluloid::Task::TerminatedError
        # Clean shutdown
      rescue => e
        WindUp.logger.error "Error fetching work: #{e}"
        after(0) { feed_pool }
      end
    end
    alias_method :start, :feed_pool

    ################
    # Flow Control #
    ################
    # Pause the #feed_pool loop
    def pause
      @paused = true
    end

    # Unpause the #feed_pool loop
    def unpause
      @paused = false
      async.feed_pool
    end

    # Check if the #feed_pool loop is paused or not
    def paused?
      @paused = false if @paused.nil?
      @paused
    end

    # Combined check to see if our #feed_pool method is ready
    def ready?
      !!(pool && store)
    rescue
      false
    end

    ###########
    # Helpers #
    ###########
    def terminate
      terminate_pool
      super
    end

    # Shortcut checker for strictness
    def strict?
      @strict
    end

    # Pool methods #
    # ------------ #
    def busy_workers
      pool.busy_size
    end

    def idle_workers
      pool.idle_size
    end

    def backlog?
      idle_workers == 0
    end

    def available?
      !backlog?
    end

    # Store methods #
    # ------------- #

    # Number of jobs in the queues
    # @return [Hash] a hash of queue names and sizes
    def size
      store.size
    end

    # List priority levels, with weights
    # @return [Hash] hash with priority level as keys and counts as values
    def priority_level_weights
      weights = {}
      weighted_priority_levels.each {|lev| weights[lev] = (weights[lev] || 0) + 1;  }
      weights
    end

    # Misc. #
    # ----- #
    def ==(other)
      (self.class.name == other.class.name) &&
      (name == other.name) &&
      (priority_level_weights == other.priority_level_weights)
    end

    private
    # Returns the priority levels in sorted order
    # @return [Array] priority levels, as according to our definitions
    def queues_for_fetch
      if priority_levels.empty?
        nil
      elsif strict?
        priority_levels.to_a
      else
        weighted_priority_levels.shuffle.uniq
      end
    end

    # Find our pool from the Celluloid registry
    # This is a back-end method; publicly, you should use #pool to find or
    # create the pool
    def find_pool
      p = Celluloid::Actor[pool_name]
      p if p.respond_to?(:perform) && p.respond_to?(:async) && p.alive?
    end
  end
end
