require "fileutils"
require "yaml"
require "pebble_runner/run_helpers"

class PebbleRunner::Starter
  include PebbleRunner::RunHelpers
  
  def initialize(name)
    run("export > /etc/envvars")
    topic "Starting proc #{name}"
    run_proc(name)
  end
end