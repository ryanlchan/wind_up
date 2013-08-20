Wind Up
=======
WindUp is a drop-in replacement for Celluloid's `PoolManager` class. So why
would you use WindUp?

* Asynchronous message passing - get all the nice worker-level concurrency
  Celluloid give you (#sleep, #Celluloid::IO, #future, etc)
* Separate proxies for QueueManager and queues - no more unexpected behavior
  between #is_a? and #class
* Single queue handles multiple workers - Extend WindUp with
  [MultiWindUp](https://www.github.com/ryanlchan/multi_wind_up) and you can
  have one pool execute multiple types of workers simultaneously

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

Changing Routing Behavior (Advanced)
------------------------------------

WindUp accepts multiple types of routing behavior. Supported behaviors include:

  * :random - Route messages to workers randomly
  * :round_robin - Route messages to each worker sequentially
  * :smallest_mailbox - Route messages to the worker with the smallest mailbox
  * :first_available - Route messages to the first available worker (Default)

To configure your queue to use a specific routing style, specify the routing
behavior when calling .queue:

```ruby
# Use a random router
Klass.queue router: :random
```

You can specify your own custom routing behavior as well:
```ruby
class FirstRouter < WindUp::Router::Base
  # Returns the next subscriber to route a message to
  def next_subscriber
    subscribers.first
  end
end

# Register this router
WindUp::Routers.register :first, FirstRouter

# Use this router
q = Klass.queue router: :first

```

Multiple worker types per queue
-------------------------------

This part of WindUp has been extracted to its own gem,
[MultiWindUp](https://www.github.com/ryanlchan/multi_wind_up).
WindUp now only contains the pooling implementation.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
