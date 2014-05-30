require "fileutils"
require "yaml"
require "pebble_runner/run_helpers"

class PebbleRunner::Runner
  include PebbleRunner::RunHelpers
  
  def initialize(args)
    topic "Attaching to shell running #{args}"
    run_exec(args)
  end
end