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

## Usage ##
Define your Wind Up queues using the WindUp DSL:
```Ruby
# config/initializers/wind_up.rb

WindUp.config do
  # 1 pool of 10 workers with 2 queues feeding in
  # :high priority queue is checked 10x as frequently as :low priority queue
  queue name: :proportional, worker: ReactorWorker, workers: 5 do
    priority_level :high, weight: 10
    priority_level :low, weight: 1
  end

  # 1 queue of 5 workers with 2 queues feeding in
  # Queues are emptied in order of definition, i.e., :first is polled until
  # empty, then :second, etc
  queue name: :strict, worker: ReactorWorker, workers: 5, strict: true do
    priority_level :first
    priority_level :second
  end

  # Use an existing SuckerPunch pool
  queue name: :existing, pool: SuckerPunch::Queue[:my_pool]
end
```
Wind Up will automatically create the relevant SuckerPunch queue upon initialization.

Speaking of, define your SuckerPunch workers as usual - no special configuration necessary:
```Ruby
# app/workers/log_worker.rb

class LogWorker
  include SuckerPunch::Worker

  def perform(event)
    Log.new(event).track
  end
end
```

Add jobs to your pools' queues using `#push`:
```Ruby
# Push to the first queue available
WindUp::Queue[:proportional].push("This is passed to #perform")

# Push to a specific queue
WindUp::Queue[:proportional].push("This is passed to #perform", priority: :high)
WindUp::Queue[:strict].push({note: "Accepts any object here"}, priority: :first)
```

Processing is automatically started upon `#push`, and is completed asynchronously.

## Persistence ##
If you'd like to persist your jobs, there is the option to use a Redis database to store jobs.
```Ruby
# Additional requirements
require 'connection_pool'
require 'redis'
require 'multi_json'

WindUp.config do
  # Supply a connection/connection_pool
  queue name: :redis, store: :redis, store_options: { connection: $REDIS }

  # or just configuration options, and we'll make the connection_pool for you
  queue name: :redis, store: :redis, store_options: { url: "redis://localhost:6379", size: 3 }

  # or leave out config entirely and we'll look through ENV vars and localhost for a Redis server
  queue name :redis,  store: :redis

```

Jobs are persisted as JSON encoded objects in lists. The convention for naming
the list keys is: "wind_up:<RAILS_ENV>:queues:<QUEUE_NAME>:<PRIORITY_LEVEL>".

## WindUp pass-through ##
Your WindUp pool methods still work:
```Ruby
WindUp::Queue[:log_queue].workers # => 10
WindUp::Queue[:log_queue].busy_workers # => 7
WindUp::Queue[:log_queue].idle_workers # => 3
WindUp::Queue[:log_queue].size # => { high: 5, low: 3 } # # of jobs enqueued
```

## Internals ##
Wind Up's queue is based on a pooled reactor pattern, consisting of two parts to this system:
  1) WindUp::Feeder, which holds all pending work for your pool of reactors
     and is responsible for queueing and ordering
  2) WindUp::Worker ("Reactors"), which performs the work passed in by WindUp::Feeder

As special class is included which

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
