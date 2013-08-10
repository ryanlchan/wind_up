require 'spec_helper'
require 'celluloid'

describe WindUp::Mailboxes::SlaveMailbox do
  let(:master) { Celluloid::Mailbox.new }
  let(:slave) { WindUp::Mailboxes::SlaveMailbox.new(master) }
  let(:freebox) { WindUp::Mailboxes::SlaveMailbox.new }

  describe '#initialize' do
    context 'when the mailbox has a master' do
      subject { slave }
      its(:master) { should be }
    end

    context 'when the mailbox does not have a master' do
      subject { freebox }
      its(:master) { should_not be }
    end
  end

  describe '#next_message_from_master' do
    context 'when the mailbox has a master' do
      context 'when the master has a pending message' do
        let(:test_message) { "Test message" }
        before(:each) { master << test_message }
        it 'retrieves the next pending message from the master mailbox' do
          slave.next_message_from_master.should be test_message
        end
      end

      context 'when the master does not have a pending message' do
        it 'returns nil after a timeout' do
          slave.next_message_from_master.should be nil
        end
      end
    end
    context 'when the mailbox does not have a master' do
      it 'returns nil' do
        freebox.next_message_from_master.should be nil
      end
    end
  end

  describe '#receive' do
    context 'when the mailbox has a master' do
      context 'and has a message in its own queue' do
        it 'returns the message in its own queue' do
          slave_message = "Slave"
          slave << slave_message
          slave.receive.should eq slave_message
        end
      end

      context 'and has no message in its own queue' do
        context 'and the master has a message' do
          it 'returns the master message' do
            test_message = "master"
            master << test_message
            slave.receive.should eq test_message
          end
        end

        context 'and the master does not have a message' do
          it 'returns nil' do
            slave.receive.should_not be
          end
        end
      end
    end
    context 'when the mailbox has no master' do
      it 'returns whatever is in its own queue' do
        free_message = "No master"
        freebox << free_message
        freebox.receive.should eq free_message
      end
    end
  end
end
