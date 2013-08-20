require 'spec_helper'

shared_examples_for 'a router' do
  describe '#add_subscriber' do
    it 'adds a subscriber to the list of subscribers' do
      subject.add_subscriber(subscriber)
      subject.subscribers.should include(subscriber)
    end
  end

  describe '#<<' do
    it 'forwards messages to a subscriber' do
      subject.add_subscriber subscriber
      subject << :ok
      subscriber.receive(0).should be :ok
    end
  end
end

describe WindUp::Routers do
  let(:subscriber) { Celluloid::Mailbox.new }
  let(:origin) { WindUp::Routers[router_class].new }
  subject { origin }

  describe WindUp::Router::RoundRobin do
    let(:router_class) { :round_robin }
    it_behaves_like 'a router'
  end

  describe WindUp::Router::Random do
    let(:router_class) { :random }
    it_behaves_like 'a router'
  end

  describe WindUp::Router::SmallestMailbox do
    let(:router_class) { :smallest_mailbox }
    it_behaves_like 'a router'
  end

  describe WindUp::Router::FirstAvailable do
    let(:router_class) { :first_avaialble }

    describe '#add_subscriber' do
      it 'adds a subscriber to the list of subscribers' do
        subject.add_subscriber(subscriber)
        subject.subscribers.should include(subscriber)
      end
    end

    describe '#<<' do
      it 'publishes the Forwarder event to all subscribers' do
        origin.add_subscriber(subscriber)
        origin << "New work"
        subscriber.receive(1).should be_a(WindUp::ForwardedCall)
      end
    end
  end
end
