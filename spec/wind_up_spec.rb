require 'spec_helper'

class FakeWorker
  include Celluloid
  def perform(*args); end;
end

describe WindUp do
  describe '.logger' do
    it "delegates get to Celluloid's logger" do
      WindUp.logger.should == Celluloid.logger
    end

    it "delegates set to Celluloid's logger" do
      Celluloid.should_receive(:logger=)
      WindUp.logger = nil
    end
  end
end
