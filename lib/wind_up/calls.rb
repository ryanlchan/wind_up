# WindUp's Forwarder call allows a mailbox to forward its messages to
# another. We slightly abuse the SyncCall class to inject the remote work
# request. Sorry.
module WindUp
  class Forwarder < Celluloid::Call

    # Do not block if no work found
    TIMEOUT = 0

    def initialize(sender)
      @sender = sender
    end

    # Pull the next message from the sender, if available
    def dispatch(obj)
      ::Celluloid.mailbox << @sender.receive(TIMEOUT)
    end
  end
end

