# A slave mailbox which, when empty, draws events from a 'Master' mailbox
module WindUp
  module Mailboxes
    class SlaveMailbox < Celluloid::Mailbox
      # Interval to poll the master mailbox on, in seconds
      POLLING_INTERVAL = 0.1

      attr_accessor :master

      def initialize(master = nil)
        super()
        @master = master
      end

      # Receive a message from the Mailbox or its Master
      def receive(timeout = nil, &block)
        message = nil
        timeout = [timeout.to_f, POLLING_INTERVAL].min

        @mutex.lock
        begin
          raise MailboxError, "attempted to receive from a dead mailbox" if @dead

          begin
            message = next_message(&block) || next_message_from_master(timeout, &block)

            unless message
              now = Time.now
              wait_until ||= now + timeout
              wait_interval = wait_until - now
              return if wait_interval <= 0

              @condition.wait(@mutex, wait_interval)
            end
          end until message

          message
        ensure
          @mutex.unlock rescue nil
        end
      end

      # Retrieve a message from this SlaveMailbox's master
      def next_message_from_master(timeout = POLLING_INTERVAL, &block)
        @master.receive(timeout, &block) if @master
      end

      # Inspect the contents of the mailbox and the mailbox's master
      def inspect
        "#<#{self.class}:#{object_id.to_s(16)} @master=#{@master.inspect} @messages=[#{map { |m| m.inspect }.join(', ')}]>"
      end
    end
  end
end
