# require 'spec_helper'

# class MissingPerform
#   def initialize(*args); end
# end

# class TestHandler
#   def initialize(*args); end
#   def perform(*args);end
# end

# describe WindUp::Workers::HandlerWorker do
#   describe '#perform' do
#     let(:worker) { WindUp::Workers::HandlerWorker.new }
#     context 'when not passed a :handler' do
#       it 'raises an exception' do
#         expect{worker.perform}.to raise_exception(WindUp::Workers::MissingHandlerName)
#       end
#     end

#     context 'when passed a :handler' do
#       context 'which does not exist' do
#         it 'raises an exception' do
#           expect{worker.perform(handler: "MissingHandler")}.to raise_exception(WindUp::Workers::InvalidHandler)
#         end
#       end
#       context 'which does exist' do
#         context 'but does not have a #perform method' do
#           it 'raises an exception' do
#             expect{worker.perform(handler: "MissingPerform")}.to raise_exception(WindUp::Workers::InvalidHandler)
#           end
#         end
#         context 'and has a #perform method' do
#           it 'initializes the handler class' do
#             TestHandler.should_receive(:new).at_least(1).times.and_call_original
#             worker.perform handler: "TestHandler"
#           end

#           it 'passes the options from the message to the initializer' do
#             TestHandler.should_receive(:new).with({test: "payload"}).at_least(1).times.and_call_original
#             worker.perform handler: "TestHandler", msg: {test: "payload"}
#           end
#         end
#       end
#     end
#   end
# end
