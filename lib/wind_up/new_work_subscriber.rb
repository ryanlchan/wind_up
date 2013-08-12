# Allows a mailbox to subscribe to another mailbox's new work updates

require 'celluloid'

module WindUp
  module NewWorkSubscriber
    # Timeout for responding to NewWorkSignals
    NEW_WORK_TIMEOUT = 0.1

    # Receive a message from the Mailbox or its Master
    def receive(timeout = nil, &block)
      msg = super
      msg = handle_new_work(msg, &block) if msg.is_a?(NewWorkSignal)
      msg
    end

    # Hook for processing a new work signal
    # @param msg [NewWorkSignal] the signal to handle
    # @return the updated work from the origin mailbox
    def handle_new_work(msg, &block)
      msg.receive(NEW_WORK_TIMEOUT, &block)
    end

    # Patch in to enable #respond_to?(new_work_signal)
    def new_work_signal
      true
    end
  end
end

# Patch Celluloid's mailbox with our new receive routine
if RUBY_VERSION < "2.0.0"
  # Ahh, Ruby 2.0, nice
  Celluloid::Mailbox.send :prepend, WindUp::NewWorkSubscriber
else
  # Woe is us! Time for some fancy metaprogramming
  Celluloid::Mailbox.class_eval do
    include WindUp::NewWorkSubscriber
    receive_without_new_work_signals = instance_method(:receive)

    define_method(:receive) do |timeout = nil, &block|
      msg = receive_without_new_work_signals.bind(self).(timeout, &block)
      msg = handle_new_work(msg) if msg.is_a?(WindUp::NewWorkSignal)
      msg
    end
  end
end

