require "fileutils"
require "yaml"
require "pebble_runner/run_helpers"

class PebbleRunner::Runner
  include PebbleRunner::RunHelpers
  
  def initialize(args, quiet=false)
    topic "Attaching to shell running #{args}" unless quiet
    run_exec(args)
  end
end