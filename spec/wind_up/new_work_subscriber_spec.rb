require 'spec_helper'

describe WindUp::NewWorkSubscriber do
  let(:mailbox) { Celluloid::Mailbox.new }
  let(:origin) { Celluloid::Mailbox.new }

  describe '.include' do
    it 'enables checking by #respond_to?(:new_work_signal)' do
      mailbox.respond_to?(:new_work_signal).should be
    end
  end

  describe '#receive' do
    context "when an enabled mailbox receives" do
      context "a NewWorkSignal" do
        let(:nws) { WindUp::NewWorkSignal.new origin }
        let(:test_message) { "test message" }
        before(:each) do
          origin << test_message
          mailbox << nws
        end

        it "calls the #receive method on the NewWorkSignal" do
          mailbox.receive.should eq test_message
        end
      end
    end
  end
end
