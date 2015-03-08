require "fileutils"
require "yaml"
require "json"
require "pebble_runner/run_helpers"
require "pebble_runner/shell_helpers"

class PebbleRunner::Builder
  include PebbleRunner::ShellHelpers
  include PebbleRunner::RunHelpers
  
  attr_accessor :app_dir, :build_root, :cache_root, :buildpack_root,
                :env_dir, :selected_buildpack, :buildpack_name, :tmptar
  
  def initialize
    set_defaults
    copy_input
    set_env
    select_buildpack
    compile
    release
    finalize
  end
  
  private
  
  def set_defaults
    @app_dir = "/app"
    @build_root = "/tmp/build"
    @cache_root = "/tmp/cache"
    @buildpack_root = "/tmp/buildpacks"
    @env_dir = "/etc/env_dir"
    @tmptar = "/tmp/app.tar"
  end
  
  # Extract stdin to app_dir and copy to build_root
  def copy_input
    error("No app passed to STDIN") if STDIN.tty?      
    
    FileUtils.mkdir_p(app_dir)
    FileUtils.mkdir_p(cache_root)
    File.open(tmptar, 'w+') { |f| f.write(STDIN.read) }
    run!("tar -xf #{tmptar} -C #{app_dir}")
    FileUtils.cp_r("#{app_dir}/.", build_root)
    FileUtils.chown_R('app', 'app', app_dir)
    FileUtils.chown_R('app', 'app', build_root)
    FileUtils.chown_R('app', 'app', cache_root)
    FileUtils.chown_R('app', 'app', buildpack_root)
  end
  
  def set_env
    user_env_hash['REQUEST_ID'] = run("openssl rand -base64 32")
    user_env_hash['APP_DIR'] = app_dir
    user_env_hash['HOME'] = app_dir
    user_env_hash['CURL_TIMEOUT'] = ENV['CURL_TIMEOUT'] || '60'
    user_env_hash['CURL_CONNECT_TIMEOUT'] = ENV['CURL_CONNECT_TIMEOUT'] || '10'
    user_env_hash['STACK'] = ENV['STACK'] || 'cedar-14'
  end
  
  def select_buildpack
    selected = nil
    
    if env('BUILDPACK_URL')
      topic "Fetching custom buildpack"
      buildpack = File.join(buildpack_root, "custom")
      FileUtils.rm_rf(buildpack)
      run!("git clone --quiet --depth=1 #{env('BUILDPACK_URL')} #{buildpack.shellescape}")
      FileUtils.chown_R('app', 'app', buildpack_root)
      name = run("#{buildpack.shellescape}/bin/detect #{build_root}")
      $?.success? && selected = buildpack
    else
      Dir["#{buildpack_root}/*"].each do |pack|
        name = run("#{pack.shellescape}/bin/detect #{build_root}")
        if $?.success?
          selected = pack
          break
        end
      end
    end
    
    selected = Pathname.new("#{selected}")
    if selected.exist? && selected.directory?
      @buildpack_name = name.strip
      topic "#{buildpack_name} app detected"
      @selected_buildpack = selected.to_s
    else
      error "Unable to select a buildpack"
    end
  end
  
  def compile
    pipe!("chpst -u app #{selected_buildpack.shellescape}/bin/compile #{build_root.shellescape} #{cache_root.shellescape} #{env_dir.shellescape}", no_indent: true, user_env: true)
  end
  
  def release
    rel = run!("chpst -u app #{selected_buildpack.shellescape}/bin/release #{build_root.shellescape} #{cache_root.shellescape} #{env_dir.shellescape}", user_env: true)
    
    File.open(File.join(build_root, ".release"), 'w') { |f| f.write(rel) }
    
    exec = <<-EOF
#!/bin/bash
include () {
    [[ -f "$1" ]] && source "$1"
}
export HOME=#{app_dir}
for file in #{app_dir}/.profile.d/*; do include \$file; done
hash -r
cd #{app_dir}
eval "$@"
EOF
    
    File.open(File.join(build_root, "exec"), 'w+') { |f| f.write(exec) }
    File.chmod(0777, File.join(build_root, "exec"))
  end
  
  def finalize
    # Copy final version of the app to app_dir
    FileUtils.rm_rf(app_dir)
    FileUtils.cp_r("#{build_root}/.", app_dir)
    FileUtils.mkdir_p(File.join(app_dir, '.profile.d'))
    FileUtils.chown_R('app', 'app', app_dir)
    
    app_size = run("du -hs #{app_dir} | cut -f1")
    puts "Compiled app size is #{app_size}"
    
    # Cleanup
    FileUtils.rm_rf(build_root)
    FileUtils.rm_rf(buildpack_root)
    FileUtils.rm(tmptar)
    
    write_built
  end
  
  def write_built
    sizek = run("du -ks #{app_dir} | cut -f1").gsub("\n", "")
    
    info = {}
    info['process_types'] = assembled_procs.to_h
    info['app_size'] = sizek.to_i * 1024
    info['buildpack_name'] = buildpack_name
    
    File.open('/.built', 'w+') { |f| f.write(JSON.dump(info)) }
    
    topic "Discovering process types"
    procfile_entries = procfile_procs.entries.map { |n,c| n }
    puts "Procfile declares types     -> #{procfile_entries.empty? ? "(none)" : procfile_entries.join(", ")}"
    puts "Default types for #{buildpack_name[0...10]} -> #{default_procs.keys.join(", ")}"
  end
  
  def self.built?
    Pathname.new('/.built').exist?
  end
end