require "fileutils"
require "yaml"
require "pebble_runner/run_helpers"

class PebbleRunner::Info
  include PebbleRunner::RunHelpers
  
  def initialize
    run_exec('cat /.built')
  end
end