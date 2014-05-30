require "shellwords"
require "pathname"
require "pebble_runner/shell_helpers"

module PebbleRunner
  module RunHelpers
    include PebbleRunner::ShellHelpers
    
    def run_exec(command)
      exec(app_env, "/app/exec chpst -u app #{command}")
    end
    
    def run_service
      pid = spawn(app_env, "/usr/bin/runsvdir -P /etc/service")

      Signal.trap("INT") do
        topic "Shutting down runit"
        Process.kill("INT", pid)
        
        done = false
        while !done
          done = system("/usr/bin/sv status /etc/service/* | grep -q '^run:'")
          sleep(0.1) if !done
        end
        
        exit
      end
      
      sleep(1) # wait for svlogd to start
      pipe("tail -f /var/log/runit/*/current", no_indent: true)
    end
    
    private
    
    def app_env
      env = {'HOME' => '/app'}
      user_env_hash.merge(env)
    end
  end
end