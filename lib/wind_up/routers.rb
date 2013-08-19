# A variant of Celluloid::Mailbox which forwards messages to subscribers
#
# Router is not a mailbox in the strict sense. It acts as a demuxer for calls,
# accepting and routing them to the next available subscriber.
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
      # List all subscribers
      def subscribers
        @subscribers ||= []
      end

      # Subscribe to this mailbox for updates of new messages
      # @param subscriber [Object] the subscriber to send messages to
      def add_subscriber(subscriber)
        subscribers << subscriber unless subscribers.include?(subscriber)
      end

      # Remove a subscriber from thie mailbox
      # @param subscriber [Object] the subscribed object
      def remove_subscriber(subscriber)
        subscribers.delete subscriber
      end

      # Send the call to all subscribers
      def <<(message)
        target = next_subscriber
        send_message(target, message) if target
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

      def alive?
        true
      end

      def shutdown
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
    class ScatterGatherFirstCompleted < Base
      def mailbox
        @mailbox ||= Celluloid::Mailbox.new
      end

      def <<(msg)
        mailbox << msg
        signal
      end

      def signal
        subscribers.each do |sub|
          sig = WindUp::ForwardedCall.new(mailbox)
          begin
            sub << sig
          rescue Celluloid::MailboxError
            # Mailbox died, remove subscriber
            remove_subscriber sub
          end
        end
        nil
      end

      def alive?
        mailbox.alive?
      end

      def shutdown
        mailbox.shutdown
      end
    end
  end

  Routers.register :scattergather, Router::ScatterGatherFirstCompleted
  Routers.register :roundrobin, Router::RoundRobin
  Routers.register :random, Router::Random
  Routers.register :smallestmailbox, Router::SmallestMailbox
end
