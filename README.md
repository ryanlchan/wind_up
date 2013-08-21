WindUp
===========

WindUp allows you to do super simple background processing using Celluloid
Actors.

Installation
------------
```ruby
# Gemspec
gem 'wind_up'
```

Usage
-----

WindUp's `Delegator` allows us to use one queue to process multiple job types.
`Delegator#perform_with` will instantiate a class and run its `#perform`
method, passing any additional arguments provided.

Create a new `Delegator` queue using the WindUp Queue method. Use
`Delegator#perform_with` to send tasks to this queue. Asynchronous processing
is accomplished the same way you would with a WindUp Queue or Celluloid Pool;
`#sync`, `#async`, and `#future` all continue to work as expected.

```ruby
# Create a Delegator queue; these are equivalent
queue = WindUp::Delegator.queue size: 3
queue = WindUp.queue size: 3

# Create a job class
class GreetingJob
  def perform(name = "Bob")
    "Hello, #{name}!"
  end
end

# Send the delayed action to the Delegator queue
queue.perform_with GreetingJob, "Hurried Harry" # => "Hello, Hurried Harry!", completed synchronously
queue.async.perform_with GreetingJob, "Mellow Mary" # => nil, work completed in background
queue.future.perform_with GreetingJob, "Telepathic Tim" # => Celluloid::Future, with value "Hello, Telepathic Tim!"

# Store this queue for later usage
Celluloid::Actor[:background] = queue
# Later...
Celluloid::Actor[:background].async.perform_with GreetingJob, "Tina"

```

Tips
----

* Don't share state from your current thread with your Jobs!

  With WindUp, your jobs will be *eventually* processed, but we have no idea
  how long it'll be. As such, your jobs and messages should not share state.
  I.e., don't pass a User object; pass a user.id and recreates the user from
  the database within your job.

* Use JSON serializable arguments for your jobs

  Not only is it a good way to prevent yourself from accidentally sharing
  state (see previous point), but if you want to use a persistant job store
  you cannot pass in any objects that can't be dumped to JSON.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
