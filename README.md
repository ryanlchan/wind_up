Wind Up
=======
WindUp is a drop-in replacement for Celluloid's `PoolManager` class. So why
would you use WindUp?

* Asynchronous message passing - worker-level concurrency on any blocking call
  (i.e. #sleep, Celluloid::IO, etc)
* Separate proxies for QueueManager and queues - no more unexpected behavior
  between #is_a? and #class
* Single queue handles multiple workers - Using WindUp's built in Delegator
  class, you can have one pool execute multiple types of workers
  simultaneously

Usage
-----

WindUp `Queues` are almost drop-in replacements for Celluloid pools.

```ruby
q = AnyCelluloidClass.queue size: 3 # size defaults to number of cores
q.any_method                # perform synchronously
q.async.long_running_method # perform asynchronously
q.future.i_want_this_back   # perform as a future
```

`Queues` use two separate proxies to control `Queue` commands vs
`QueueManager` commands.
```ruby
# .queue returns the proxy for the queue (i.e. workers)
q = AnyCelluloidClass.queue # => WindUp::QueueProxy(AnyCelluloidClass)

# Get the proxy for the manager from the QueueProxy
q.__manager__ # => Celluloid::ActorProxy(WindUp::QueueManager)

# Return to the queue from the manager
q.__manager__.queue # WindUp::QueueProxy(AnyCelluloidClass)
```

You may store these `Queue` object in the registry as any actor
```ruby
Celluloid::Actor[:queue] = q
```

Multiple worker types per queue
-------------------------------

Ever wish you could reuse the same background worker pool for multiple types
of work? WindUp's `Delegator` was designed to solve this
problem.`Delegator#perform_with` will instantiate the class and run its
#perform method with any additional arguments provided

Use just like a WindUp Queue or Celluloid Pool; `#sync`, `#async`, and
  `#future` all work

Usage
-----
Create a new `Delegator` queue using the WindUp Queue method. Use
`Delegator#perform_with` to perform tasks in the background.

```ruby
# Create a Delegator queue
queue = WindUp::Delegator.queue size: 3

# Create a job class
class GreetingJob
  def perform(name = "Bob")
    "Hello, #{name}!"
  end
end

# Send the delayed action to the Delegator queue
queue.async.perform_with GreetingJob, "Mary" # => nil, work completed in background
queue.future.perform_with GreetingJob, "Tim" # => Celluloid::Future, with value "Hello, Tim!"
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
