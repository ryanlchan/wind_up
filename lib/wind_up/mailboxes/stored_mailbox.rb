# An extension of the Celluloid mailbox to utilize WindUp's store API
module WindUp
  module Mailboxes
    class StoredMailbox < Celluloid::Mailbox

      # Initialize a StoredMailbox with the given storage backend
      # @param options [Hash] the options to initialize with
      # @option options [Symbol] :store the type of storage backend to use
      # @option options [Object] :connection the connection to use for the store
      # @option options [String] :url the Redis connection url
      # @option options [String] :size the connection pool size [Default = 3]
      # @option options [String] :timeout the connection pool timeout [Default = 5]
      def initialize(options = {})
        super
        options = { :store => :memory }.merge options
        @store = Store.new(options)
        @system_events = []
      end

      # Add a message to the Mailbox
      def <<(message)
        @mutex.lock
        begin
          if message.is_a?(SystemEvent)
            # Silently swallow system events sent to dead actors
            return if @dead

            # SystemEvents are high priority messages so they get added to our special queue
            @system_events.unshift message
          else
            raise MailboxError, "dead recipient" if @dead
            @store.push message
          end

          @condition.signal
          nil
        ensure
          @mutex.unlock rescue nil
        end
      end

      ## TODO NONE OF THESE ARE COMPLETED ##

      # Receive a message from the Mailbox
      def receive(timeout = nil, &block)
        message = nil

        @mutex.lock
        begin
          raise MailboxError, "attempted to receive from a dead mailbox" if @dead

          begin
            message = next_message(&block)

            unless message
              if timeout
                now = Time.now
                wait_until ||= now + timeout
                wait_interval = wait_until - now
                return if wait_interval <= 0
              else
                wait_interval = nil
              end

              @condition.wait(@mutex, wait_interval)
            end
          end until message

          message
        ensure
          @mutex.unlock rescue nil
        end
      end

      # Retrieve the next message in the mailbox
      def next_message
        message = nil

        if block_given?
          index = @messages.index do |msg|
            yield(msg) || msg.is_a?(SystemEvent)
          end

          message = @messages.slice!(index, 1).first if index
        else
          message = @messages.shift
        end

        message
      end

      # Shut down this mailbox and clean up its contents
      def shutdown
        @mutex.lock
        begin
          messages = @messages
          @messages = []
          @dead = true
        ensure
          @mutex.unlock rescue nil
        end

        messages.each { |msg| msg.cleanup if msg.respond_to? :cleanup }
        true
      end

      # Is the mailbox alive?
      def alive?
        !@dead
      end

      # Cast to an array
      def to_a
        @mutex.synchronize { @messages.dup }
      end

      # Iterate through the mailbox
      def each(&block)
        to_a.each(&block)
      end

      # Inspect the contents of the Mailbox
      def inspect
        "#<#{self.class}:#{object_id.to_s(16)} @messages=[#{map { |m| m.inspect }.join(', ')}]>"
      end

      # Number of messages in the Mailbox
      def size
        @mutex.synchronize { @messages.size }
      end

      private
      def mailbox_full
        @max_size && @messages.size >= @max_size
      end
    end
  end
end
