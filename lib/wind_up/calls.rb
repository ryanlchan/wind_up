module WindUp
  # WindUp's ForwardedCall tells an actor to pull a message from a source
  # mailbox when processed
  class ForwardedCall < Celluloid::Call

    # Do not block if no work found
    TIMEOUT = 0

    def initialize(source)
      @source = source
    end

    # Pull the next message from the source, if available
    def dispatch(obj)
      msg = @source.receive(TIMEOUT)
      ::Celluloid.mailbox << msg if msg
    end
  end

  # Wraps a TerminationRequest for standard ordering within a mailbox
  class DelayedTerminationRequest < Celluloid::Call
    def initialize
      @method = :terminate
    end
  end
end

