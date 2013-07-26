require 'spec_helper'

class IntegrationWorker
  include Celluloid

  def self.messages
    @@messages ||= {}
  end

  def self.reset!
    mesages = {}
  end

  def perform(*args)
    self.class.messages << args
  end;
end

class IntegrationQueue
  include WindUp::Queue
  worker_class IntegrationWorker
end

describe 'Integration Test', integration: true do
  let(:payload) { {work: "Message", user: 1} }
  it 'pushes and processes work' do
    IntegrationWorker.any_instance.should_receive(:perform).with(payload)
    IntegrationQueue.push payload
    IntegrationQueue.unpause # Force us to run payload now
    sleep 0.1
  end
end
