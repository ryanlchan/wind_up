# A duck-type of Celluloid::Mailbox which forwards messages to subscribers
#
# Router is not a mailbox in the strict sense. It acts as a forwarder for
# calls, accepting and routing them to the next available subscriber. As with
# Akka routers, pushing a call onto a Router is invoked concurrently from the
# sender and must be threadsafe.
module WindUp
  module Routers
    def self.register(name, klass)
      registry[name] = klass
    end

    def self.registry
      @registry ||= {}
    end

    def self.[](name)
      registry[name] || registry.values.first
    end
  end

  module Router
    class Base
      def initialize
        @mutex = Mutex.new
      end

      # List all subscribers
      def subscribers
        @subscribers ||= []
      end

      # Subscribe to this mailbox for updates of new messages
      # @param subscriber [Object] the subscriber to send messages to
      def add_subscriber(subscriber)
        @mutex.synchronize do
          subscribers << subscriber unless subscribers.include?(subscriber)
        end
      end

      # Remove a subscriber from thie mailbox
      # @param subscriber [Object] the subscribed object
      def remove_subscriber(subscriber)
        @mutex.synchronize do
          subscribers.delete subscriber
        end
      end

      # Send the call to all subscribers
      def <<(message)
        @mutex.lock
        begin
          target = next_subscriber
          send_message(target, message) if target
        ensure
          @mutex.unlock rescue nil
        end
      end

      def broadcast(message)
        send_message(subscribers, message)
      end

      # Send a message to the specified target
      def send_message(target, message)
        # Array-ize unless we're an Enumerable already that isn't a Mailbox
        target = [target] unless target.is_a?(Enumerable) && !target.respond_to?(:receive)

        target.each do |targ|
          begin
            targ << message
          rescue Celluloid::MailboxError
            # Mailbox died, remove subscriber
            remove_subscriber targ
          end
        end
        nil
      end
    end

    # Randomly route messages to workers
    class Random < Base
      def next_subscriber
        subscribers.sample
      end
    end

    # Basic router using a RoundRobin strategy
    class RoundRobin < Base
      # Signal new work to all subscribers/waiters
      def next_subscriber
        subscribers.rotate!
        subscribers.last
      end
    end

    # Send message to the worker with the smallest mailbox
    class SmallestMailbox < Base
      def next_subscriber
        subscribers.sort { |a,b| a.size <=> b.size }.first
      end
    end

    # The strategy employed is similar to a ScatterGatherFirstCompleted router in
    # Akka, but wrapping messages in the ForwardedCall structure so computation is
    # only completed once.
    class FirstAvailable < Base
      def mailbox
        @mailbox ||= Celluloid::Mailbox.new
      end

      def <<(msg)
        @mutex.lock
        begin
          mailbox << msg
          send_message(subscribers, WindUp::ForwardedCall.new(mailbox))
        ensure
          @mutex.unlock rescue nil
        end
      end

      def shutdown
        mailbox.shutdown
      end
    end
  end

  Routers.register :first_avaialble, Router::FirstAvailable
  Routers.register :round_robin, Router::RoundRobin
  Routers.register :random, Router::Random
  Routers.register :smallest_mailbox, Router::SmallestMailbox
end
