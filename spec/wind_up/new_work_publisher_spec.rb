require 'spec_helper'

describe WindUp::NewWorkPublisher do
  let(:mailbox) { Celluloid::Mailbox.new }
  let(:origin) { WindUp::PublisherMailbox.new }

  describe '#add_subscriber' do
    it 'adds a subscriber to the list of subscribers' do
      origin.add_subscriber(mailbox)
      origin.subscribers.should include(mailbox)
    end
  end

  describe '#<<' do
    it 'publishes the Forwarder event to all subscribers' do
      origin.add_subscriber(mailbox)
      mailbox.should_receive(:<<).with(kind_of(WindUp::Forwarder))
      origin << "New work"
    end
  end
end
