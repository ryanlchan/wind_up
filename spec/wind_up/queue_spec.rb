require 'spec_helper'

class FakeWorker
  include Celluloid
  def perform(*args); end;
end

describe WindUp::Queue do
  describe ".[]" do
    it "delegates to Celluloid" do
      Celluloid::Actor[:fake] = FakeWorker.pool
      Celluloid::Actor.should_receive(:[]).with(:fake)
      WindUp::Queue[:fake]
    end
  end

  describe ".store" do
    context "by default" do
      it "returns the InMemory store" do
        WindUp::Queue.store.should be WindUp::Store::InMemory
      end
    end
    context "when passed :memory or 'memory'" do
      it "returns the InMemory store" do
        WindUp::Queue.store(:memory).should be WindUp::Store::InMemory
        WindUp::Queue.store("memory").should be WindUp::Store::InMemory
      end
    end
    context "when passed :redis or 'redis'" do
      it "returns the Redis store" do
        WindUp::Queue.store(:redis).should be WindUp::Store::Redis
        WindUp::Queue.store("redis").should be WindUp::Store::Redis
      end
    end
  end

  describe '#push' do
    context 'when not given a priority level' do
      it 'pushes the argument to the store with default priority' do
        WindUp.config { queue name: :pusher, worker: FakeWorker, workers: 2 }
        WindUp::Queue[:pusher].store.should_receive(:push).with("test", priority_level: nil)
        WindUp::Queue[:pusher].push "test"
      end
    end
    context 'when given a priority level' do
      it 'pushes the argument to the store with specified priority' do
        WindUp.config { queue name: :pusher, worker: FakeWorker, workers: 2 }
        WindUp::Queue[:pusher].store.should_receive(:push).with("test", priority_level: "high")
        WindUp::Queue[:pusher].push "test", priority_level: "high"
      end
    end
  end

  describe '#pop' do
    context 'without a priority level argument' do
      context 'with a strictly ordered queue' do
        it 'pops priority levels in order' do
          WindUp.config do
            queue name: :strict_popper, worker: FakeWorker, workers: 2, strict: true do
              priority_level :high
              priority_level :low
            end
          end
          WindUp::Queue[:strict_popper].store.should_receive(:pop).with([:high, :low]).at_least(1).times
          WindUp::Queue[:strict_popper].pop
        end
      end
      context 'with a loosely ordered queue' do
        it 'pops priority levels in proportion' do
          WindUp.config do
            queue name: :loose_popper, worker: FakeWorker, workers: 2 do
              priority_level :high
              priority_level :low
            end
          end
          WindUp::Queue[:loose_popper].store.stub(:pop) { nil }
          WindUp::Queue[:loose_popper].store.stub(:pop).with { [:high, :low] }.and_return { "success" }
          WindUp::Queue[:loose_popper].store.stub(:pop).with { [:low, :high] }.and_return { "success" }

          WindUp::Queue[:loose_popper].pop.should be
        end
      end
    end
    context 'with a priority_level argument' do
      it 'pops the specified priority' do
        WindUp.config { queue name: :popper, worker: FakeWorker, workers: 2 }
        WindUp::Queue[:popper].store.stub(:pop) { nil }
        WindUp::Queue[:popper].store.stub(:pop).with(["queue"]) { "work" }
        WindUp::Queue[:popper].pop(["queue"]).should be
      end
    end
  end

  describe '#workers' do
    it 'returns the number of workers in the pool' do
      WindUp.config { queue name: :workers_test, worker: FakeWorker, workers: 2 }
      WindUp::Queue[:workers_test].workers.should eq 2
    end
  end

  describe '#busy_workers' do
    it 'returns the number of busy_workers in the pool' do
      WindUp.config { queue name: :busy_workers, worker: FakeWorker, workers: 2 }
      WindUp::Queue[:busy_workers].busy_workers.should eq 0
    end
  end

  describe '#idle_workers' do
    it 'returns the number of idle_workers in the pool' do
      WindUp.config { queue name: :idle_workers, worker: FakeWorker, workers: 2 }
      WindUp::Queue[:idle_workers].idle_workers.should eq 2
    end
  end

  describe '#backlog?' do
    it 'returns true if the pool is fully utilized' do
      WindUp.config { queue name: :backlog, worker: FakeWorker, workers: 2 }
      WindUp::Queue[:backlog].should_not be_backlog
    end
  end

  describe '#size' do
    it 'returns the number of jobs in the queue store' do
      WindUp.config { queue name: :size, worker: FakeWorker, workers: 2 }
      WindUp::Queue[:size].store.should_receive(:size).and_return(4)
      WindUp::Queue[:size].size.should eq 4
    end
  end

  describe '#strict?' do
    context 'when the queue is strictly ordered' do
      it 'returns true' do
        WindUp.config { queue name: :strict, worker: FakeWorker, workers: 2, strict: true }
        WindUp::Queue[:strict].should be_strict
      end
    end
    context 'when the queue is not strictly ordered' do
      it 'returns false' do
        WindUp.config { queue name: :not_strict, worker: FakeWorker, workers: 2 }
        WindUp::Queue[:not_strict].should_not be_strict
      end
    end
  end

  describe '#priority_levels' do
    context 'with a queue with priority levels' do
      it 'returns the priority levels for this queue' do
        WindUp.config do
          queue name: :pls, worker: FakeWorker, workers: 2 do
            priority_level :high
            priority_level :low
          end
        end
        WindUp::Queue[:pls].priority_levels.should eq [:high, :low]
      end

      it 'does not return duplicates' do
        WindUp.config do
          queue name: :pls, worker: FakeWorker, workers: 2 do
            priority_level :high, weight: 10
            priority_level :low, weight: 1
          end
        end
        WindUp::Queue[:pls].priority_levels.should eq [:high, :low]
      end
    end
    context 'with a queue without priority levels' do
      it 'returns an empty array' do
        WindUp.config { queue name: :no_pl, worker: FakeWorker, workers: 2 }
        WindUp::Queue[:no_pl].priority_levels.should eq []
      end
    end
  end

  describe '#priority_level_weights' do
    context 'when run on a queue without priority levels' do
      it 'returns an empty hash' do
        WindUp.config { queue name: :no_pl, worker: FakeWorker, workers: 2 }
        WindUp::Queue[:no_pl].priority_level_weights.should eq({})
      end
    end

    context 'when run on a queue with unweighted priority levels' do
      it "returns the priority levels with their weightings" do
        WindUp.config do
          queue name: :upl, worker: FakeWorker, workers: 2 do
            priority_level :high
            priority_level :low
          end
        end
        WindUp::Queue[:upl].priority_level_weights.should eq({high: 1, low: 1})
      end
    end

    context 'when run on a queue with unweighted priority levels' do
      it "returns the priority levels with their weightings" do
        WindUp.config do
          queue name: :wpl, worker: FakeWorker, workers: 2 do
            priority_level :high, weight: 10
            priority_level :low, weight: 1
          end
        end
        WindUp::Queue[:wpl].priority_level_weights.should eq({high: 10, low: 1})
      end
    end
  end

  describe '#default_priority_level' do
    context 'when run on a queue without priority levels' do
      it 'returns nil' do
        WindUp.config { queue name: :no_pl, worker: FakeWorker, workers: 2 }
        WindUp::Queue[:no_pl].default_priority_level.should_not be
      end
    end

    context 'when run on a queue with priority levels' do
      it "returns the first priority level" do
        WindUp.config do
          queue name: :upl, worker: FakeWorker, workers: 2 do
            priority_level :high
            priority_level :low
          end
        end
        WindUp::Queue[:upl].default_priority_level.should eq(:high)
      end
    end

    context 'when run on a queue with a default priority level explicitly set' do
      it "returns the set priority level" do
        WindUp.config do
          queue name: :wpl, worker: FakeWorker, workers: 2, default_priority_level: :low do
            priority_level :high, weight: 10
            priority_level :low, weight: 1
          end
        end
        WindUp::Queue[:wpl].default_priority_level.should eq(:low)
      end
    end
  end
end
