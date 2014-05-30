require "fileutils"
require "yaml"
require "pebble_runner/shell_helpers"

class PebbleRunner::Builder
  include PebbleRunner::ShellHelpers
  
  attr_accessor :pushed_dir, :app_dir, :build_root, :cache_root, :buildpack_root,
                :env_dir, :selected_buildpack, :buildpack_name
  
  def initialize
    set_defaults
    copy_input
    set_env
    select_buildpack
    compile
    release
    discover_services
    write_services
    write_env
    cleanup
  end
  
  private
  
  def set_defaults
    @pushed_dir = "/pushed"
    @app_dir = "/app"
    @build_root = "/tmp/build"
    @cache_root = "/tmp/cache"
    @buildpack_root = "/tmp/buildpacks"
    @env_dir = "/etc/env_dir"
  end
  
  def copy_input
    FileUtils.rm_rf(app_dir)
    FileUtils.rm_rf(build_root)
    FileUtils.cp_r("#{pushed_dir}/.", app_dir)
    FileUtils.cp_r("#{app_dir}/.", build_root)
  end
  
  def set_env
    user_env_hash['REQUEST_ID'] = run("openssl rand -base64 32")
    user_env_hash['APP_DIR'] = app_dir
    user_env_hash['HOME'] = app_dir
    user_env_hash['CURL_TIMEOUT'] = '120'
    user_env_hash['CURL_CONNECT_TIMEOUT'] = '5'
  end
  
  def select_buildpack
    selected = nil
    
    if env('BUILDPACK_URL')
      topic "Fetching custom buildpack"
      buildpack = File.join(buildpack_root, "custom")
      FileUtils.rm_rf(buildpack)
      run!("git clone --quiet --depth=1 #{env('BUILDPACK_URL')} #{buildpack.shellescape}")
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
    pipe!("#{selected_buildpack.shellescape}/bin/compile #{build_root.shellescape} #{cache_root.shellescape} #{env_dir.shellescape}", no_indent: true, user_env: true)
  end
  
  def release
    rel = run!("#{selected_buildpack.shellescape}/bin/release #{build_root.shellescape} #{cache_root.shellescape} #{env_dir.shellescape}", user_env: true)
    File.open(File.join(build_root, ".release"), 'w') do |f|
      f.write(rel)
    end
  end
  
  def discover_services
    topic "Discovering process types"
    
    if Pathname.new("#{build_root}/Procfile").exist?
      types = YAML.load_file(File.join(build_root, "Procfile")).keys().join(', ')
      puts "Procfile declares types -> #{types}"
    end
    
    if Pathname.new("#{build_root}/.release").exist?
      types = (YAML.load_file(File.join(build_root, ".release"))['default_process_types'] || {}).keys().join(', ')
      puts "Default process types for #{buildpack_name} -> #{types}"
    end
  end
  
  def write_services
    if Pathname.new("#{build_root}/Procfile").exist?
      puts "Writing Procfile services to /etc/service"
      
      (YAML.load_file(File.join(build_root, "Procfile")) || {}).each do |name, cmd|
        runit_service(name, cmd)
      end
    else
      puts "Writing default services to /etc/service"
      
      (YAML.load_file(File.join(build_root, ".release"))['default_process_types'] || {}).each do |name, cmd|
        next if %w(rake console).include?(name)
        runit_service(name, cmd)
      end
    end
  end
  
  def write_env
    FileUtils.mkdir_p(File.join(build_root, ".profile.d"))
    (YAML.load_file(File.join(build_root, ".release"))['config_vars'] || {}).each do |k,v|
      File.open(File.join(build_root, ".profile.d", "config_vars"), 'a+') do |f|
        f.write("export #{k}=#{v}\n")
      end
    end
    
    exec = <<-EOF
#!/bin/bash
export HOME=/app
for file in /app/.profile.d/*; do source \$file; done
hash -r
cd /app
"\$@"
EOF
    
    File.open(File.join(build_root, "exec"), 'w+') { |f| f.write(exec) }
    File.chmod(0777, File.join(build_root, "exec"))
  end
  
  def cleanup
    FileUtils.rm_rf(app_dir)
    FileUtils.cp_r("#{build_root}/.", app_dir)
    FileUtils.chown_R('app', 'app', app_dir)
    
    app_size = run("du -hs #{app_dir} | cut -f1")
    puts "Compiled app size is #{app_size}"
    
    FileUtils.rm_rf(build_root)
    FileUtils.rm_rf(buildpack_root)
    
    FileUtils.touch('/.built')
  end
  
  def self.built?
    Pathname.new('/.built').exist?
  end
  
  private
  
  def runit_service(name, cmd)
    runner = <<-EOF
#!/bin/sh
exec 2>&1
exec chpst -u app /app/exec #{cmd}
EOF

    logger = <<-EOF
#!/bin/sh
exec svlogd -tt /var/log/runit/#{name}
EOF

    FileUtils.mkdir_p("/etc/service/#{name}/log")
    FileUtils.mkdir_p("/var/log/runit/#{name}")
    
    File.open("/etc/service/#{name}/run", 'w+') { |f| f.write(runner) }
    File.chmod(0777, "/etc/service/#{name}/run")
    
    File.open("/etc/service/#{name}/log/run", 'w+') { |f| f.write(logger) }
    File.chmod(0777, "/etc/service/#{name}/log/run")
  end
end