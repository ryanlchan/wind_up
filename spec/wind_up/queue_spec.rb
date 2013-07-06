require 'spec_helper'

class FakeWorker
  include Celluloid
  def perform(*args); end;
end

# Because we use a Singleton model, it's tough to change configurations
# without redefining a ton of classes. This class just helps us dynamically
# create Queue classes using a block.
class QueueFactory
  ALPHABET = ('a'..'z').to_a
  def self.bake(&block)
    c = Class.new
    name = 10.times.map{ ALPHABET.sample }.join.capitalize
    Object.const_set(name, c)

    c.send(:include, WindUp::Queue)
    if block_given?
      c.instance_eval &block
    else
      c.instance_eval {
        worker_class FakeWorker
      }
    end
    return c
  end
end

describe WindUp::Queue do
  let(:queue) { QueueFactory.bake }
  describe "#store" do
    context "by default" do
      it "sets the InMemory store" do
        queue.store.should be_a(WindUp::Store::InMemory)
      end
    end
    context "when passed :memory or 'memory'" do
      it "sets the InMemory store" do
        queue.store(:memory).should be_a(WindUp::Store::InMemory)
        queue.store("memory").should be_a(WindUp::Store::InMemory)
        queue.store.should be_a(WindUp::Store::InMemory)
      end
    end
    context "when passed :redis or 'redis'" do
      it "sets the Redis store" do
        queue.store(:redis).should be_a(WindUp::Store::Redis)
        queue.store("redis").should be_a(WindUp::Store::Redis)
        queue.store.should be_a(WindUp::Store::Redis)
      end

      context "with a :url provided" do
        it "uses the url to connect to Redis" do
          queue.store(:redis, url: "redis://127.0.0.1:6379")
          queue.store.should be
        end
      end

      context 'with :connection set to a Redis client instance' do
        it 'works' do
          redis = Redis.new
          queue.store(:redis, connection: redis)
          queue.store.should be
        end
      end

      context 'with :connection set to a Redis connection_pool' do
        it 'works' do
          redis = ConnectionPool.new(size: 2, timeout: 5) { Redis.new }
          queue.store(:redis, connection: redis)
          queue.store.should be
        end
      end
    end
  end

  context '#pool' do
    context 'configured using :workers/:worker' do
      let(:queue) do
        QueueFactory.bake do
          worker_class FakeWorker
          workers 3
        end
      end

      it "sets up the SuckerPunch queue" do
        queue.pool.should be
        queue.pool.size.should eq 3
      end
    end

    context ':pool_name' do
      context 'when given an existing pool' do
        it 'uses the existing pool' do
          Celluloid::Actor[:pool_name_spec] = FakeWorker.pool size: 2
          queue = QueueFactory.bake do
            pool_name :pool_name_spec
          end
          queue.pool.should be Celluloid::Actor[:pool_name_spec]
        end
      end
    end
  end

  context '#priority_level' do
    context 'that are equal' do
      it 'creates a queue with priority levels' do
        queue = QueueFactory.bake do
          worker_class FakeWorker
          priority_level :clone1
          priority_level :clone2
        end

        queue.should be
        queue.priority_levels.should_not be_empty
      end
    end

    context 'that are weighted' do
      it 'creates a queue with priority levels' do
        queue = QueueFactory.bake do
          worker_class FakeWorker
          priority_level :high, weight: 10
          priority_level :low, weight: 1
        end

        queue.should be
        queue.priority_levels.should_not be_empty
        queue.priority_level_weights.should eq({high: 10, low: 1})
      end
    end

    context 'that are strictly ordered' do
      it 'creates a queue with priority levels' do
        queue = QueueFactory.bake do
          worker_class FakeWorker
          strict true
          priority_level :clone1
          priority_level :clone2
        end

        queue.should be
        queue.priority_levels.should_not be_empty
        queue.should be_strict
      end
    end
  end # with priority leels

  describe '#push' do
    context 'when not given a priority level' do
      it 'pushes the argument to the store with default priority' do
        queue.store.should_receive(:push).with("test", priority_level: nil)
        queue.push "test"
      end
    end
    context 'when given a priority level' do
      it 'pushes the argument to the store with specified priority' do
        queue.store.should_receive(:push).with("test", priority_level: "high")
        queue.push "test", priority_level: "high"
      end
    end
  end

  describe '#pop' do
    context 'without a priority level argument' do
      context 'with a strictly ordered queue' do
        it 'pops priority levels in order' do
          queue = QueueFactory.bake do
            worker_class FakeWorker
            strict true
            priority_level :high
            priority_level :low
          end
          queue.store.should_receive(:pop).with([:high, :low]).at_least(1).times
          queue.pop
        end
      end
      context 'with a loosely ordered queue' do
        it 'pops priority levels in proportion' do
          queue = QueueFactory.bake do
            worker_class FakeWorker
            priority_level :high
            priority_level :low
          end
          queue.store.stub(:pop) { nil }
          queue.store.stub(:pop).with { [:high, :low] }.and_return { "success" }
          queue.store.stub(:pop).with { [:low, :high] }.and_return { "success" }

          queue.pop.should be
        end
      end
    end
    context 'with a priority_level argument' do
      it 'pops the specified priority' do
        queue.store.stub(:pop) { nil }
        queue.store.stub(:pop).with(["queue"]) { "work" }
        queue.pop(["queue"]).should be
      end
    end
  end

  describe '#workers' do
    it 'returns the number of workers in the pool' do
      queue = QueueFactory.bake do
        worker_class FakeWorker
        workers 2
      end
      queue.workers.should eq 2
    end
  end

  describe '#busy_workers' do
    it 'returns the number of busy_workers in the pool' do
      queue = QueueFactory.bake do
        worker_class FakeWorker
        workers 2
      end
      queue.busy_workers.should eq 0
    end
  end

  describe '#idle_workers' do
    it 'returns the number of idle_workers in the pool' do
      queue = QueueFactory.bake do
        worker_class FakeWorker
        workers 2
      end
      queue.idle_workers.should eq 2
    end
  end

  describe '#backlog?' do
    it 'returns true if the pool is fully utilized' do
      queue = QueueFactory.bake do
        worker_class FakeWorker
      end
      queue.should_not be_backlog
    end
  end

  describe '#size' do
    it 'returns the number of jobs in the queue store' do
      queue.store.should_receive(:size).and_return(4)
      queue.size.should eq 4
    end
  end

  describe '#strict?' do
    context 'when the queue is strictly ordered' do
      it 'returns true' do
        queue = QueueFactory.bake do
          worker_class FakeWorker
          strict true
        end
        queue.should be_strict
      end
    end
    context 'when the queue is not strictly ordered' do
      it 'returns false' do
        queue = QueueFactory.bake do
          worker_class FakeWorker
        end
        queue.should_not be_strict
      end
    end
  end

  describe '#priority_levels' do
    context 'with a queue with priority levels' do
      it 'returns the priority levels for this queue' do
        queue = QueueFactory.bake do
          worker_class FakeWorker
          priority_level :high
          priority_level :low
        end
        queue.priority_levels.should eq [:high, :low]
      end

      it 'does not return duplicates' do
        queue = QueueFactory.bake do
          worker_class FakeWorker
          priority_level :high, weight: 10
          priority_level :low, weight: 1
        end
        queue.priority_levels.should eq [:high, :low]
      end
    end
    context 'with a queue without priority levels' do
      it 'returns an empty array' do
        queue = QueueFactory.bake do
          worker_class FakeWorker
        end
        queue.priority_levels.should eq []
      end
    end
  end

  describe '#priority_level_weights' do
    context 'when run on a queue without priority levels' do
      it 'returns an empty hash' do
        queue = QueueFactory.bake do
          worker_class FakeWorker
        end
        queue.priority_level_weights.should eq({})
      end
    end

    context 'when run on a queue with unweighted priority levels' do
      it "returns the priority levels with their weightings" do
        queue = QueueFactory.bake do
          worker_class FakeWorker
          priority_level :high
          priority_level :low
        end
        queue.priority_level_weights.should eq({high: 1, low: 1})
      end
    end

    context 'when run on a queue with unweighted priority levels' do
      it "returns the priority levels with their weightings" do
        queue = QueueFactory.bake do
          worker_class FakeWorker
          priority_level :high, weight: 10
          priority_level :low, weight: 1
        end
        queue.priority_level_weights.should eq({high: 10, low: 1})
      end
    end
  end

  describe '#default_priority_level' do
    context 'when run on a queue without priority levels' do
      it 'returns nil' do
        queue = QueueFactory.bake do
          worker_class FakeWorker
        end
        queue.default_priority_level.should_not be
      end
    end

    context 'when run on a queue with priority levels' do
      it "returns the first priority level" do
        queue = QueueFactory.bake do
          worker_class FakeWorker
          priority_level :high
          priority_level :low
        end
        queue.default_priority_level.should eq(:high)
      end
    end

    context 'when run on a queue with a default priority level explicitly set' do
      it "returns the set priority level" do
        queue = QueueFactory.bake do
          worker_class FakeWorker
          priority_level :high, weight: 10
          priority_level :low, weight: 1, default: true
        end
        queue.default_priority_level.should eq(:low)
      end
    end
  end
end
