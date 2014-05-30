#!/bin/bash

if [ -e "/etc/.provisioned" ] ; then
  echo "VM already provisioned.  Remove /etc/.provisioned to force"
  exit 0
fi

minimal_apt_get_install='apt-get install -y --no-install-recommends'

## Temporarily disable dpkg fsync to make building faster.
echo force-unsafe-io > /etc/dpkg/dpkg.cfg.d/02apt-speedup

## Install packages
sed -i 's/^#\s*\(deb.*universe\)$/\1/g' /etc/apt/sources.list
sed -i 's/^#\s*\(deb.*multiverse\)$/\1/g' /etc/apt/sources.list
apt-get update

$minimal_apt_get_install linux-image-extra-`uname -r` lxc wget nano htop git-core

## Docker
echo deb https://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
apt-get update
$minimal_apt_get_install lxc-docker
service docker restart
usermod -a -G docker vagrant

## Test app
git clone https://github.com/heroku/ruby-rails-sample.git /vagrant/sample

## Cleanup
apt-get clean
rm -rf /build
rm -rf /tmp/* /var/tmp/*
rm -rf /var/lib/apt/lists/*
rm -f /etc/dpkg/dpkg.cfg.d/02apt-speedup

touch /etc/.provisioned
