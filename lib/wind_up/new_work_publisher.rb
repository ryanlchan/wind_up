# Enable a mailbox to be subscribed to for new work updates

# TODO: Generalize from Observer/Subject to real Pub/Sub

module WindUp
  module NewWorkPublisher
    # List all subscribers
    def subscribers
      @subscribers ||= Set.new
    end

    # Subscribe to this mailbox for updates of new work
    # @param subscriber [Object] the subscriber to send NewWorkSignals to
    def add_subscriber(subscriber)
      subscribers << subscriber
    end

    # Hook into the add work method to publish the new work event
    def <<(message)
      super
      publish
      nil
    end

    private
    # Sends out a NewWorkSignal to all subscribers
    def publish
      subscribers.each do |sub|
        nws = WindUp::NewWorkSignal.new self
        begin
          sub << nws
        rescue Celluloid::MailboxError
          # Mailbox died, remove subscriber
          subscribers.delete(sub)
        end
      end
      nil
    end
  end
end
