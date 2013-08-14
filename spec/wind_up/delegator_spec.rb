require 'spec_helper'

class MissingPerform; end

class TestHandler
  def perform(*args)
    if args.size > 0
      :args
    else
      :done
    end
  end
end

class TestQueuer
  def perform(queue)
    queue << :done
  end
end


describe WindUp::Delegator do
  describe '#perform_with' do
    let(:worker) { WindUp::Delegator.new }
    context 'when not passed a delegatee' do
      it 'raises an exception' do
        mute_celluloid_logging do
          expect{ worker.perform_with }.to raise_exception
        end
      end
    end

    context 'when passed a delegatee' do
      context 'but does not have a #perform method' do
        it 'raises an exception' do
          mute_celluloid_logging do
            expect{ worker.perform_with MissingPerform }.to raise_exception(WindUp::InvalidDelegatee)
          end
        end
      end
      context 'and has a #perform method' do
        it 'initializes the handler class' do
          worker.perform_with(TestHandler).should eq :done
        end

        it 'passes the arguments from the method' do
          worker.perform_with(TestHandler, :argument).should eq :args
        end
      end
    end
  end

  context 'when queued' do
    let(:queue) { WindUp::Delegator.queue }
    it 'returns synchronously' do
      queue.perform_with(TestHandler).should eq :done
    end

    it 'returns asynchronously' do
      q = Queue.new
      queue.async.perform_with TestQueuer, q
      q.pop.should eq :done
    end

    it 'returns as a future' do
      f = queue.future.perform_with TestHandler
      f.value.should eq :done
    end
  end
end
