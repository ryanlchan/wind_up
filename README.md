Wind Up
=======
Wind Up brings the power of Sidekiq's flexible and multiqueues to wind_up's simplicity.

## Installation ##

Add wind_up to your Gemfile:

    gem 'wind_up'

Install your bundle:

    $ bundle

Or install separately:

    $ gem install wind_up

## Configuration ##

WindUp queues are defined declaratively using a DSL. The preferred way to
create a queue is to define a class and include the WindUp::Queue module,
using class macros to configure the Queue:

```Ruby
# app/queues/new_queue.rb

class NewQueue
  include WindUp::Queue

  name :proportional    # name
  worker ReactorWorker
  workers 5
end
```

However, sometimes you don't know what kind of queues you need before hand. In
those cases, you can use WindUp::Queue.new to dynamically instantiate a queue
using the same class macro DSL:

```Ruby
require 'wind_up'

NewQueue = WindUp::Queue.new do
  name :proportional
  worker ReactorWorker
  workers 5
end
```

### Priority Levels ###

WindUp supports defining priority levels for incoming messages. Prioritization
can occur in two modes:

  * Proportional, in which each level is assigned a weight and is accesses at
    a proportionate frequency; aka [Weighted Fair Queueing](http://en.wikipedia.org/wiki/Weighted_fair_queuing) (Default)
  * Strict, in which each level is accessed in order of definition until empty

Priority levels are also defined using WindUp's DSL class macros:

```Ruby
class PrioritizedQueue
  include WindUp::Queue

  # Equal levels, proportional access
  priority_level :a
  priority_level :b

  # Unequal levels; :twice is accessed 2x as frequently as :once
  priority_level :twice, weight: 2
  priority_level :once,  weight: 1

  # Strictly ordered; messages are drawn from :first until empty, then from
  # :second, etc
  strict true
  priority_level :first
  priority_level :second
end
```

## Usage ##

Queues are created as singletons and are accessed using class methods.
Processing is automatically started, and is completed asynchronously.

Add jobs to your pools' queues using the `.push` method.
```Ruby
NewQueue.push("This is passed to #perform")
```

Pause and resume processing of the Queue using the `.pause` and `.resume`.
```Ruby
NewQueue.pause    # pauses processing of queue jobs
NewQueue.unpause  # resume processing
NewQueue.paused?  # check if the queue is processing
```

## Persistence ##
If you'd like to persist your jobs, there is the option to use a Redis database to store jobs.
```Ruby
# Additional requirements
require 'connection_pool'
require 'redis'
require 'multi_json'

class NewQueue
  # By default we look through ENV vars and localhost for a Redis server
  store :redis

  # Supply a connection/connection_pool
  store :redis, { connection: $REDIS }

  # or just configuration options, and we'll make the connection_pool for you
  store :redis, { url: "redis://localhost:6379", size: 3 }
end
```

Jobs are persisted as JSON encoded objects in lists. The convention for naming
the list keys is: "wind_up:<RAILS_ENV>:queues:<QUEUE_NAME>:<PRIORITY_LEVEL>".

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
