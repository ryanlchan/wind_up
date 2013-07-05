require 'spec_helper'

class FakeWorker
  include Celluloid
  def perform(*args); end;
end

describe WindUp do
  describe ".config" do
    describe '.queue' do
      it 'creates the WindUp queue' do
        WindUp.config do
          queue name: :config_queue, worker: FakeWorker, workers: 3
        end

        WindUp::Queue[:config_queue].should be
      end

      it "registers the queue with the API" do
        WindUp::API::Queues.should_receive(:register).with(:fake)
        WindUp.config { queue name: :fake, worker: FakeWorker }
      end

      context ':name' do
        context 'when the name is already taken' do
          it 'terminates and replaces the existing actor' do
            original = FakeWorker.supervise_as :duplicate
            WindUp.config { queue name: :duplicate, worker: FakeWorker, workers: 2 }
            WindUp::Queue[:duplicate].should be_a(WindUp::Queue)
          end
        end
      end

      context ":store" do
        context "set to :redis" do
          context "with connection set to nil" do
            it "loads the local_host" do
              WindUp.config { queue name: :redis, worker: FakeWorker, store: :redis }
              WindUp::Queue[:redis].should be
            end
          end

          context "with a url provided" do
            it "uses the url to connect to Redis" do
              WindUp.config { queue name: :redis_local, worker: FakeWorker, store: :redis, store_options: { url: "redis://127.0.0.1:6379"} }
              WindUp::Queue[:redis_local].should be
            end
          end

          context 'with connection set to a Redis client instance' do
            it 'works' do
              redis = Redis.new
              WindUp.config { queue name: :redis_conn, worker: FakeWorker, store: :redis, store_options: {connection: redis} }
              WindUp::Queue[:redis_conn].should be
            end
          end

          context 'with connection set to a Redis connection_pool' do
            it 'works' do
              redis = ConnectionPool.new(size: 2, timeout: 5) { Redis.new }
              WindUp.config { queue name: :redis_pool, worker: FakeWorker, store: :redis, store_options: {connection: redis} }
              WindUp::Queue[:redis_pool].should be
            end
          end
        end
      end

      context 'with the connection pool configured using' do
        context ':workers/:worker' do
          it "sets up the SuckerPunch queue" do
            WindUp.config {queue name: :pool_queue, worker: FakeWorker, workers: 3}

            SuckerPunch::Queue[:"pool_queue:pool"].should be
            SuckerPunch::Queue[:"pool_queue:pool"].size.should eq 3
          end
        end

        context ':pool' do
          it 'uses the existing SuckerPunch queue' do
            SuckerPunch.config { queue name: :existing_pool, worker: FakeWorker, workers: 2 }
            pool = SuckerPunch::Queue[:existing_pool]
            pool.should be
            WindUp.config { queue name: :existing, pool: pool }
            WindUp::Queue[:existing].should be
            SuckerPunch::Queue["existing:pool"].should be pool
          end
        end
      end

      context '#priority_level' do
        context 'that are equal' do
          it 'creates a queue with priority levels' do
            WindUp.config do
              queue name: :equal_pl, worker: FakeWorker, workers: 3 do
                priority_level :clone1
                priority_level :clone2
              end
            end

            WindUp::Queue[:equal_pl].should be
            WindUp::Queue[:equal_pl].priority_levels.should_not be_empty
          end
        end

        context 'that are weighted' do
          it 'creates a queue with priority levels' do
            WindUp.config do
              queue name: :weighted_pl, worker: FakeWorker, workers: 3 do
                priority_level :high, weight: 10
                priority_level :low, weight: 1
              end
            end

            WindUp::Queue[:weighted_pl].should be
            WindUp::Queue[:weighted_pl].priority_levels.should_not be_empty
            WindUp::Queue[:weighted_pl].priority_level_weights.should eq({high: 10, low: 1})
          end
        end

        context 'that are strictly ordered' do
          it 'creates a queue with priority levels' do
            WindUp.config do
              queue name: :crazy_queue, worker: FakeWorker, workers: 3, strict: true do
                priority_level :first
                priority_level :second
              end
            end

            WindUp::Queue[:crazy_queue].should be
            WindUp::Queue[:crazy_queue].priority_levels.should_not be_empty
            WindUp::Queue[:crazy_queue].should be_strict
          end
        end
      end # with priority leels
    end # .queue
  end # .config

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
