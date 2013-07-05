require 'spec_helper'

describe WindUp::API::Queues do
  describe "queue registration and querying" do
    it "adds a queue to the master queue list" do
      WindUp::API::Queues.register(:fake)
      expect(WindUp::API::Queues.all).to include(:fake)
    end
  end
end
