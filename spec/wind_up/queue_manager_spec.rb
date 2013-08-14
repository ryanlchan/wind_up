require 'spec_helper'

class FakeWorker
  include Celluloid
  def process(queue = nil)
    if queue
      queue << :done
    else
      :done
    end
  end

  def crash
    raise StandardError, "zomgcrash"
  end
end

class SleepyWorker < FakeWorker
  def sleepy
    sleep 0.2
    :done
  end
end


describe WindUp::QueueManager do
  let(:queue) { FakeWorker.queue size: 2 }
  describe '#initialize' do
    it 'creates a supervision group of workers' do
      expect { FakeWorker.queue size: 1 }.to change { Celluloid::Actor.all.size }.by(2)
    end

    it 'creates as many workers as number of cores on the system' do
      cores = FakeWorker.queue
      cores.__manager__.size.should eq Celluloid.cores
    end

    it 'requires a worker class' do
      mute_celluloid_logging do
        expect { WindUp::QueueManager.new }.to raise_exception
        sleep 0.1
      end
    end
  end

  describe '#terminate' do
    it 'terminates the manager' do
      queue.terminate
      queue.should_not be_alive
    end

    it 'terminates the pool' do
      expect{ queue.terminate }.to change { Celluloid::Actor.all.size }.by(0)
    end
  end

  describe '#sync' do
    it 'processs calls synchronously' do
      queue.process.should be :done
    end
  end

  describe '#async' do
    it 'processs calls asynchronously' do
      q = Queue.new
      queue.async.process(q)
      q.pop.should be :done
    end

    it 'processes additional work when workers as sleeping' do
      sleepy_queue = SleepyWorker.queue size: 1
      start_time = Time.now
      vals = 2.times.map { sleepy_queue.future.sleepy }
      vals.each { |v| v.value }
      (start_time - Time.now).should be < 0.3
    end

    it 'handles crashed calls gracefully' do
      mute_celluloid_logging do
        queue.async.crash
        queue.should be_alive
      end
    end
  end

  describe '#future' do
    it 'processes calls as futures' do
      f = queue.future.process
      f.value.should be :done
    end
  end

  describe '#size=' do
    let(:manager) { queue.__manager__ }
    it 'increases the size of the pool' do
      manager.size.should eq 2
      expect { manager.size = 3 }.to change{ Celluloid::Actor.all.size }.by(1)
    end

    it 'reduces the size of the pool' do
      manager.size.should eq 2
      expect { manager.size = 1 }.to change{ Celluloid::Actor.all.size }.by(-1)
    end
  end
end
