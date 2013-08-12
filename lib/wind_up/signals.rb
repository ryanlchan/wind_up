# WindUp's NewWorkSignal allows a mailbox to signal to another mailbox the
# presence of new work. NewWorkSignal also provies a #receive method in order
# to check the originating mailbox for the new work.
module WindUp
  class NewWorkSignal
    attr_accessor :origin

    def initialize(origin)
      @origin = origin
    end

    def method_missing(method, *args, &block)
      @origin.send method, *args, &block
    end

    def respond_to?(duck)
      @origin.respond_to? duck
    end
  end
end

