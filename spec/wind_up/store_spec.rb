require 'spec_helper'

shared_examples_for 'a WindUp::Store' do
  let(:payload) { "Testing WindUp!" }
  describe '#push' do
    context 'without a priority level set' do
      it 'pushes an argument onto the default level' do
        store.push payload
      end
    end

    context 'with a priority level set' do
      it 'pushes an argument onto that specific priority level' do
        store.push payload, priority_level: :low
      end
    end
  end

  describe '#pop' do
    context 'without a priority level set' do
      it 'pops an argument off the default level' do
        store.push payload
        store.pop.should eq payload
      end

      it 'pops an argument off any existing level' do
        store.push payload, priority_level: :high
        store.pop.should eq payload
      end
    end

    context 'with a priority level set' do
      it 'pushes an argument onto that specific priority level' do
        store.push payload, priority_level: :low
        store.pop(:low).should eq payload
      end

      it 'pops queues following the argument ordering' do
        store.push payload, priority_level: :low
        store.push "showstealer pro trial version", priority_level: :high
        store.pop([:low, :high]).should eq payload
      end
    end
  end

  describe '#size' do
    context 'when the store is empty' do
      it 'returns an empty hash' do
        store.size.should eq({})
      end
    end

    context 'when the store has items' do
      it 'returns a hash with names as keys and item counts as values' do
        2.times { store.push payload, priority_level: :low }
        store.push payload, priority_level: :high
        store.size.should eq({ low: 2, high: 1 })
      end
    end
  end
end

describe WindUp::Store do
  describe WindUp::Store::InMemory do
    let(:store) { WindUp::Store::InMemory.new :memory }
    it_should_behave_like 'a WindUp::Store'
  end

  describe WindUp::Store::Redis do
    let(:store) { WindUp::Store::Redis.new :redis }
    before(:each) { store.reset! }
    it_should_behave_like 'a WindUp::Store'
  end
end
