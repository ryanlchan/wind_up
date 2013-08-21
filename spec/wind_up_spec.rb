require 'spec_helper'

describe WindUp do
  describe '.queue' do
    it 'creates a delegator queue' do
      WindUp.queue.should be_a(WindUp::Delegator)
    end
  end
end
