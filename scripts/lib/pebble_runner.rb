require "pebble_runner/builder"
require "pebble_runner/runner"
require "pebble_runner/starter"

module PebbleRunner
  class Init
    def self.start(command, arg=nil)
      built = PebbleRunner::Builder.built?
      if command == 'build' && !built
        return PebbleRunner::Builder.new
      end
      
      case command
      when "run"
        PebbleRunner::Runner.new(arg)
      when "start"
        PebbleRunner::Starter.new(arg)
      else
        puts "PebbleRunner usage:"
        puts "      build          build app pushed into container" unless built
        puts "      run <command>  run a command in the app environment"
        puts "      start <name>   run a command defined in the Procfile"
      end
    end
  end
end