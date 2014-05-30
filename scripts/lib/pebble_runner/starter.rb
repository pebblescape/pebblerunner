require "fileutils"
require "yaml"
require "pebble_runner/run_helpers"

class PebbleRunner::Starter
  include PebbleRunner::RunHelpers
  
  def initialize
    topic "Starting services"
    run_service
  end
end