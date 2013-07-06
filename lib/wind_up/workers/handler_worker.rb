# A basic example worker
# ---
# * Handler Worker will instantiate a class with the message and run its
#   #perform method
# * Use anywhere you have a single set of computing resources that should be
#   distributed to multiple types of tasks
# * Think of it as a VM host, and your Handler class as the guest
module WindUp
  module Workers
    class MissingHandlerName < StandardError; end
    class InvalidHandler < StandardError; end

    class HandlerWorker
      include Worker

      # Instantiate the referenced class and run the #perform action
      # @param msg [Hash] the options to instantiate with
      # @option msg [String] :handler the name of the handler class, as a String
      # @option msg [Object] :msg message to pass to the initializer
      # @note We use a String representation of a class to reduce the number
      #     of mutable objects passed into the store
      def perform(msg = {})
        raise MissingHandlerName unless msg[:handler]

        begin
          klass = Object.const_get msg[:handler]
        rescue NameError
          raise InvalidHandler, "No handler defined by #{msg[:handler]}" unless klass
        end

        handler = klass.new msg[:msg]
        raise InvalidHandler, "#{klass.name} does not have a #perform method defined" unless handler.respond_to?(:perform)

        handler.perform
      end
    end
  end
end
