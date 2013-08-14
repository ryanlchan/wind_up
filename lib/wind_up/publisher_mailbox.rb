# A variant of Celluloid::Mailbox which publishes updates to subscribers about
# new work, using WindUp's NewWorkPublisher module
module WindUp
  class PublisherMailbox < Celluloid::Mailbox
    include WindUp::NewWorkPublisher

    # Add a message to the Mailbox
    # Slight modification of Celluloid::Mailbox to *not* fast-track system events
    def <<(message)
      @mutex.lock
      begin
        if mailbox_full
          Logger.debug "Discarded message: #{message}"
          return
        end
        raise MailboxError, "dead recipient" if @dead
        @messages << message

        @condition.signal
        publish
        nil
      ensure
        @mutex.unlock rescue nil
      end
    end
  end
end
