require 'multi_json'
require 'redis'
require 'connection_pool'

module WindUp
  module Store
    class Redis
      TIMEOUT = 1

      # Initialize a Redis persisting store
      # @param options [Hash] the connection options
      # @option options [ConnectionPool, Redis] :connection the connection or connection_pool to use required
      def initialize(name, options = {})
        @name = name
        @prefix = "wind_up:#{environment}:queues:#{name}:"
        @conn = find_redis_config(options)
        @keys = Set.new [:default]
      end

      def push(args, priority_level: nil)
        priority_level ||= :default

        @keys << priority_level # Store key for later retrieval
        key = prefix(priority_level)
        encoded = MultiJson.dump args

        with_connection { |redis| redis.rpush(key, encoded) }
      end
      alias_method :<<, :push

      def pop(levels = [])
        levels = !levels.nil? && levels.size > 0 ? levels : @keys
        levels = [levels] unless levels.respond_to? :inject
        val = with_connection { |redis| redis.blpop( prefix(levels), timeout: TIMEOUT ) }
        MultiJson.load(val[1]) unless val.nil?
      end
      alias_method :fetch, :pop

      # Return the size of any non-zero queues
      def size
        sz = Hash[@keys.map {|k| [k, with_connection{ |r| r.llen(prefix(k)) }] }]
        sz.delete_if { |k,v| v == 0 }
      end

      # Resets the Redis DB
      def reset!
        with_connection do |redis|
          keys = redis.keys(prefix("*"))
          redis.del(keys) unless keys.empty?
        end
      end

      private
      def prefix(append = nil)
        if append.respond_to? :map
          append.map { |el| prefix el }
        else
          "#{@prefix}#{append}"
        end
      end

      def environment
        ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'none'
      end

      def with_connection
        if @conn.respond_to? :with
          @conn.with do |pool|
            yield pool
          end
        else
          yield @conn
        end
      end

      def find_redis_config(options = {})
        options = {size: 3, timeout: 5}.merge options
        if options[:connection] && options[:connection].respond_to?(:blpop)
          options[:connection]
        else
          env_var = ENV['REDIS_PROVIDER'] || 'REDIS_URL'
          url = options[:url] || ENV[env_var] || "redis://localhost:6379/0"
          ConnectionPool.new(size: options[:size], timeout: options[:timeout]) { ::Redis.connect(url: url) }
        end
      end
    end
  end
end
