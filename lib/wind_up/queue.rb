# Inspired by Mike Perham's Sidekiq::Fetcher class, this queue will initialize
# our pool of workers through SuckerPunch, then continuously retrieve jobs
# through the specified storage strategy
module WindUp
  class Queue
    include WindUp::Worker
    attr_reader :name

    # Ugly hack to get our configuration DSL to execute properly
    # Celluloid will wrap any block in a BlockProxy object, which creates a
    # new context around the DSL. This macro allows us to circumvent the
    # BlockProxy wrapper and execute on our object context
    execute_block_on_receiver :initialize

    # Initialize a new Queue
    # @param options [Hash] the options to initialize with
    # @param &block [Hash] a configuration block using WindUp's DSL
    # @option options [String] :name name to use with SuckerPunch
    # @option options [Hash] :default_priority_level priority level to use if none given

    # @note Set either :worker/:workers or :pool; pool takes priority when both are set
    # @option options [Class] :worker the worker to use
    # @option options [Integer] :workers the number of workers to use
    # @option options [Celluloid::Pool] :pool use an existing pool of workers

    # @note Redis store will attempt to connect using :connection, :url, ENV vars, then fallback to localhost
    # @option options [:redis, :memory] :store the type of store to use (currently accepts: :redis, :memory) [Default = :memory]
    # @option options [Hash] :store_options the type of store to use
    # @option store_options [Redis] :connection the connection to use for the store
    # @option store_options [String] :url the Redis connection url
    # @option store_options [String] :size the connection pool size [Default = 3]
    # @option store_options [String] :timeout the connection pool timeout [Default = 5]
    def initialize(options, &block)
      @name = options[:name]
      @strict = !!options[:strict]

      # Configure persistance
      store_options = options[:store_options] || {}
      @store = Queue.store(options[:store]).new( name, store_options )

      # Configure pool
      pool_options = options.dup.tap{ |x| x[:name] = pool_name }
      @pool = create_pool(pool_options)

      # Configure using DSL
      if block_given?
        if block.arity.abs == 1
          yield self
        else
          instance_eval &block
        end
      end
      @default_priority_level = options[:default_priority_level]

      register
    end

    def self.[](name)
      Celluloid::Actor[name]
    end

    #################
    # Configuration #
    #################
    # Return a persistance strategy for this option
    # @param store_name [String] the name of the storage option
    # @return [WindUp::Store] the storage strategy
    def self.store(store_name = nil)
      case store_name
      when :redis, 'redis'
        Store::Redis
      else
        Store::InMemory
      end
    end

    # Create or register the SuckerPunch pool of workers
    # @return [Celluloid::Pool] the pool of workers
    def create_pool(options)
      pool_name = options[:name]

      # Register existing pool under our pool_name
      if options[:pool].respond_to? :perform
        Celluloid::Actor[pool_name] = options[:pool]
        options[:pool]

      # Create a new pool
      else
        SuckerPunch.config do
          queue options
        end
        SuckerPunch::Queue[pool_name]
      end
    end

    # Create a new priority level for this queue
    def priority_level(priority_level_name, options = {})
      [options[:weight].to_i, 1].max.times { weighted_priority_levels << priority_level_name }
      priority_levels << priority_level_name
    end

    # Register this queue with the WindUp API
    def register
      WindUp::API::Queues.register name
    end

    ###########
    # Queuing #
    ###########
    # Access this queue's storage strategy
    # Typically you shouldn't need to do this
    # @return [WindUp::Store] the storage strategy employed
    def store
      @store
    end

    # Push a message onto the queue
    # @param args [Object] the object to pass to the workers
    # @param opts [Hash] the options to push with
    # @option opts [String] :priority_level the priority level to push this message to
    def push(args, opts = {})
      opts = {priority_level: default_priority_level}.merge(opts)
      store.push args, opts
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
      @pool ||= Celluloid::Actor[pool_name]
    end

    # Continually fetches new work for the pool whenever a worker is available
    # We use a self-referential schedule to avoid blocking the worker, which
    # allows us to do things like push new jobs and such.
    def feed_pool
      begin
        if feed_ready?
          if available_workers?
            work = fetch
            if work
              WindUp.logger.debug "Sending work to pool: #{work}"
              pool.async.perform(work)
            end
          end
          after(0) { feed_pool }
        end
      rescue Task::TerminatedError
        # Clean shutdown
      rescue => e
        WindUp.logger.error "Error fetching work: #{e}"
        after(0) { feed_pool }
      end
    end

    ################
    # Flow Control #
    ################
    # Pause the #feed_pool loop
    def pause_feed
      @paused = true
    end

    # Unpause the #feed_pool loop
    def unpause_feed
      @paused = false
      async.feed_pool
    end

    # Check if the #feed_pool loop is paused or not
    def feed_paused?
      @paused = false if @paused.nil?
      @paused
    end

    # Combined check to see if our #feed_pool method is ready
    def feed_ready?
      !feed_paused? && pool && store
    end


    ###########
    # Helpers #
    ###########
    # Delegated SuckerPunch methods
    def workers
      pool.size
    end

    def busy_workers
      pool.busy_size
    end

    def idle_workers
      pool.idle_size
    end

    def backlog?
      idle_workers.size == 0
    end

    def available_workers?
      !backlog?
    end

    # Number of jobs in the queues
    # @return [Hash] a hash of queue names and sizes
    def size
      store.size
    end

    # Check strict priority_level ordering, i.e., queues are emptied in the order
    # they were defined.
    # @return [Boolean] true if strict ordering of priority levels
    def strict?
      @strict
    end

    # Return the priority levels for this Queue
    # @return [Array] an array of priority levels, in order of definition
    def priority_levels
      @priority_levels ||= []
    end

    # List priority levels, with weights
    # @return [Hash] hash with priority level as keys and counts as values
    def priority_level_weights
      weights = {}
      weighted_priority_levels.each {|lev| weights[lev] = (weights[lev] || 0) + 1;  }
      weights
    end

    # The default priority level to push into
    def default_priority_level
      @default_priority_level ||= priority_levels.first
    end

    def ==(other)
      (self.class.name == other.class.name) &&
      (name == other.name) &&
      (priority_level_weights == other.priority_level_weights)
    end

    private
    def weighted_priority_levels
      @weighted_priority_levels ||= []
    end

    # Returns the priority levels in sorted order
    # @return [Array] priority levels, as according to our definitions
    def queues_for_fetch
      if priority_levels.empty?
        nil
      elsif strict?
        priority_levels.dup
      else
        weighted_priority_levels.shuffle.uniq
      end
    end

    def pool_name
      "#{name}:pool"
    end
  end
end
