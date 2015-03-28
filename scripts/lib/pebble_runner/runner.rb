require "fileutils"
require "yaml"
require "pebble_runner/run_helpers"

class PebbleRunner::Runner
  include PebbleRunner::RunHelpers
  
  def initialize(args)
    run_exec(args)
  end
end