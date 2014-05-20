#!/bin/bash
set -eo pipefail

input_dir=/pushed
app_dir=/app
build_root=/tmp/build
cache_root=/tmp/cache
buildpack_root=/tmp/buildpacks
env_dir=/etc/container_environment

mkdir -p $cache_root
mkdir -p $buildpack_root

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

## Produce slug

rm -rf $app_dir/*
cp -r $build_root/. $app_dir
  
app_size=$(du -hs "$app_dir" | cut -f1)
echo_title "Compiled app size is $app_size"

# Cleanup
rm -rf $build_root
rm -rf $buildpack_root
rm $env_dir/*
