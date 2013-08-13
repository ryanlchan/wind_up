# A variant of Celluloid::Mailbox which publishes updates to subscribers about
# new work, using WindUp's NewWorkPublisher module
module WindUp
  class PublisherMailbox < Celluloid::Mailbox
    include WindUp::NewWorkPublisher
  end
end
