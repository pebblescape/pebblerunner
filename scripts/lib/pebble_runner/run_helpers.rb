require "yaml"
require "shellwords"
require "pathname"
require "pebble_runner/procfile"
require "pebble_runner/shell_helpers"

module PebbleRunner
  module RunHelpers
    include PebbleRunner::ShellHelpers
    
    def run_exec(command)
      exec(app_env, "/app/exec chpst -u app #{command.gsub('$', '\$')}")
    end
    
    def run_proc(name)
      begin
        command = assembled_procs[name]
        
        if command
          run_exec(command)
        else
          error "No such process type"
        end
      rescue
        error "Procfile missing or invalid"
      end
    end
    
    private
    
    def app_env
      env = {'HOME' => '/app'}
      user_env_hash.merge(env)
    end
    
    def default_procs
      (YAML.load_file("/app/.release")['default_process_types'] || {})
    end
    
    def assembled_procs
      procfile = PebbleRunner::Procfile.new('/app/Procfile')
      default_procs.each do |key, cmd|
        procfile[key] = cmd unless procfile[key]
      end
      procfile
    end
  end
end