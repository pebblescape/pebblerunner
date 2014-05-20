#!/bin/bash
set -eo pipefail

input_dir=/pushed
app_dir=/app
build_root=/tmp/build
cache_root=/tmp/cache
buildpack_root=/tmp/buildpacks
env_dir=/etc/container_environment
init_dir=/etc/my_init.d

mkdir -p $cache_root
mkdir -p $buildpack_root
mkdir -p $init_dir

function echo_title() {
  echo $'\e[1G----->' $*
}

function echo_normal() {
  echo $'\e[1G      ' $*
}

function ensure_indent() {
  while read line; do
    if [[ "$line" == --* ]]; then
      echo $'\e[1G'$line
    else
      echo $'\e[1G      ' "$line"
    fi

  done 
}

## Load source

cp -r $input_dir/. $app_dir

# In heroku, there are two separate directories, and some
# buildpacks expect that.
cp -r $app_dir/. $build_root

## Buildpack fixes

export REQUEST_ID=$(openssl rand -base64 32)
export APP_DIR="$app_dir"
export HOME="$app_dir"

## Buildpack detection

buildpacks=($buildpack_root/*)
selected_buildpack=

if [[ -n "$BUILDPACK_URL" ]]; then
	echo_title "Fetching custom buildpack"

	buildpack="$buildpack_root/custom"
	rm -fr "$buildpack"
	git clone --quiet --depth=1 "$BUILDPACK_URL" "$buildpack"
	selected_buildpack="$buildpack"
	buildpack_name=$($buildpack/bin/detect "$build_root") && selected_buildpack=$buildpack
else
    for buildpack in "${buildpacks[@]}"; do
    	buildpack_name=$($buildpack/bin/detect "$build_root") && selected_buildpack=$buildpack && break
    done
fi

if [[ -n "$selected_buildpack" ]]; then
	echo_title "$buildpack_name app detected"
	else
	echo_title "Unable to select a buildpack"
	exit 1
fi

## Buildpack compile

$selected_buildpack/bin/compile "$build_root" "$cache_root" "$env_dir" | ensure_indent
$selected_buildpack/bin/release "$build_root" "$cache_root" "$env_dir" > $build_root/.release

## Display process types

echo_title "Discovering process types"
if [[ -f "$build_root/Procfile" ]]; then
	types=$(ruby -e "require 'yaml';puts YAML.load_file('$build_root/Procfile').keys().join(', ')")
	echo_normal "Procfile declares types -> $types"
fi
default_types=""
if [[ -s "$build_root/.release" ]]; then
	default_types=$(ruby -e "require 'yaml';puts (YAML.load_file('$build_root/.release')['default_process_types'] || {}).keys().join(', ')")
	[[ $default_types ]] && echo_normal "Default process types for $buildpack_name -> $default_types"
fi

## Create runit services

if [[ -f "$build_root/Procfile" ]]; then
  ruby -e "require 'yaml'; require 'fileutils'; (YAML.load_file('$build_root/Procfile') || {}).each { |name, cmd| FileUtils.mkdir_p(\"/etc/service/#{name}\"); File.open(\"/etc/service/#{name}/run\", 'w+') {|f| f.write(\"#\!/bin/sh\ncd $app_dir\nexec \" + cmd) }; File.chmod(0777, \"/etc/service/#{name}/run\"); }"
  echo_normal "Writing Procfile services to /etc/service"
else
  ruby -e "require 'yaml'; require 'fileutils'; (YAML.load_file('$build_root/.release')['default_process_types'] || {}).each { |name, cmd| next if %w(rake console).include?(name); FileUtils.mkdir_p(\"/etc/service/#{name}\"); File.open(\"/etc/service/#{name}/run\", 'w+') {|f| f.write(\"#\!/bin/sh\ncd $app_dir\nexec \" + cmd) }; File.chmod(0777, \"/etc/service/#{name}/run\"); }"
  echo_normal "Writing default services to /etc/service"
fi

## Set env vars

rm $env_dir/*

cd $build_root
if [[ -s .release ]]; then
  ruby -e "require 'yaml';(YAML.load_file('.release')['config_vars'] || {}).each{|k,v| File.open(\"$env_dir/#{k}\", 'w+') {|f| f.write(v) }; }"
fi

echo "$app_dir/vendor/bundle/ruby/2.1.0:$GEM_PATH" > $env_dir/GEM_PATH
echo "en_US.UTF-8"  > $env_dir/LANG
echo "$app_dir/bin:$app_dir/vendor/bundle/bin:$app_dir/vendor/bundle/ruby/2.1.0/bin:$PATH"  > $env_dir/PATH

## Produce slug

rm -rf $app_dir/*
cp -r $build_root/. $app_dir
  
app_size=$(du -hs "$app_dir" | cut -f1)
echo_title "Compiled app size is $app_size"

# Cleanup
rm -rf $build_root
rm -rf $buildpack_root
rm $env_dir/*
