require "yaml"
require "shellwords"
require "pathname"
require "pebble_runner/procfile"
require "pebble_runner/shell_helpers"

module PebbleRunner
  module RunHelpers
    include PebbleRunner::ShellHelpers
    
    def run_exec(command)
      exec("/app/exec #{command.gsub('$', '\$')}")
    end
    
    def run_proc(name)
      begin
        command = assembled_procs[name]
        svpath = File.join("/etc/services-available", "app-#{name}")
        
        if command && Dir.exist?(svpath)
          FileUtils.ln_s(svpath, '/etc/service', force: true)
          exec("/usr/bin/runsvdir -P /etc/service")
        else
          error "No such process type"
        end
      rescue
        error "Procfile missing or invalid"
      end
    end
    
    private
    
    def default_procs
      (YAML.load_file("/app/.release")['default_process_types'] || {})
    end
    
    def procfile_procs
      if File.exist?('/app/Procfile')
        PebbleRunner::Procfile.new('/app/Procfile')
      else
        PebbleRunner::Procfile.new
      end
    end
    
    def assembled_procs
      procfile = procfile_procs
      default_procs.each do |key, cmd|
        procfile[key] = cmd unless procfile[key]
      end
      procfile
    end
  end
end