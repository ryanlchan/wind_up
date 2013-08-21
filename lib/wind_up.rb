require 'wind_up/delegator'
require 'wind_up/version'

module WindUp
  def self.queue(opts = {})
    Delegator.queue opts
  end
end
