require 'singleton'
# Turn a class into a Celluloid singlton
# A Celluloid Singleton acts much like a normal singleton, but instead of
# keeping a local reference of instance, it uses the Celluloid Actor registry
module WindUp
  module Singleton
    def self.included(base)
      super
      base.send(:extend, ClassMethods)
      base.instance_eval {
        @singleton__mutex__ = Mutex.new
      }
      base
    end

    module ClassMethods
      def retrieve_actor
        Celluloid::Actor[self.name.to_sym]
      end

      def register_actor
        supervise_as self.name.to_sym
      end

      def instance
        return retrieve_actor if retrieve_actor
        @singleton__mutex__.synchronize {
          return retrieve_actor if retrieve_actor
          register_actor
        }
        retrieve_actor
      end

      def new
        if retrieve_actor
          retrieve_actor
        else
          super
        end
      end

      def singleton_mutex
        @singleton__mutex__
      end
    end
  end
end
