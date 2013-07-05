module WindUp
  class Railtie < ::Rails::Railtie
    initializer "wind_up.logger" do
      WindUp.logger = Rails.logger
    end
  end
end
