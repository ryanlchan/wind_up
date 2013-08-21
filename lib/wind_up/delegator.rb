# A worker to enable flexible, queue-based background processing
# ---
# Ever wish you could reuse the same background worker pool for multiple types
# of work? WindUp's `Delegator` was designed to solve this problem.
#
# `Delegator#perform_with` will instantiate the class and run its
#   #perform method with any additional arguments provided
# * Gracefully handles errors/crashes
# * Use just like a WindUp Queue or Celluloid Pool; `#sync`, `#async`, and
#   `#future` all work
#
# Usage
# -----
# Create a new `Delegator` queue using the WindUp Queue method. Use
# `Delegator#perform_with` to perform tasks in the background.
#
# ```ruby
# # Create a Delegator queue
# queue = WindUp::Delegator.queue size: 3
#
# # Create a job class
# class GreetingJob
#   def perform(name = "Bob")
#     "Hello, #{name}!"
#   end
# end
#
# # Send the delayed action to the Delegator queue
# queue.async.perform_with GreetingJob, "Mary" # => nil, work completed in background
# queue.future.perform_with GreetingJob, "Tim" # => Celluloid::Future, with value "Hello, Tim!"
#
# # Store your queue for future usage
# Celluloid::Actor[:greeting_queue] = queue
# ```
module WindUp
  class InvalidDelegatee < StandardError; end

  class Delegator
    include Celluloid

    # Instantiate the referenced class and run the #perform action
    # @param delegatee [Class] the class to delegate to
    # @return [Object] the return value of the action
    def perform_with(delegatee, *args)
      handler = delegatee.new
      raise InvalidDelegatee, "#{delegatee} does not have a #perform method defined" unless handler.respond_to?(:perform)
      handler.perform *args
    end
  end
end
