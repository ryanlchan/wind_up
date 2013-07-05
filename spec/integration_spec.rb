require 'spec_helper'

class FakeWorker
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

describe 'Integration Test', integration: true do
  let(:payload) { {work: "Message", user: 1} }
  it 'pushes and processes work' do
    WindUp.config { queue name: :integration, worker: FakeWorker, workers: 2 }
    FakeWorker.any_instance.should_receive(:perform).with(payload)
    WindUp::Queue[:integration].push payload
    sleep 0.1 # Necessary to give our background task the time to process the queue
  end
end
