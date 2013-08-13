# WindUp's NewWorkSignal allows a mailbox to signal to another mailbox the
# presence of new work. We slightly abuse the SyncCall class to inject the
# remote work request. Sorry.
module WindUp
  class NewWorkSignal < Celluloid::Call

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

