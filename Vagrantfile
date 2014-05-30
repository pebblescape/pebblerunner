# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant::Config.run do |config|
  config.vm.box = "trusty64"
  config.vm.box_url = "http://cloud-images.ubuntu.com/vagrant/trusty/current/trusty-server-cloudimg-amd64-vagrant-disk1.box"
  config.vm.provision :shell, :path => "provision.sh"
  config.ssh.forward_agent = true
end

Vagrant.configure("2") do |config|
    config.vm.provider :virtualbox do |v|
        v.customize ["modifyvm", :id, "--memory", 2048]
    end
    config.vm.provider :vmware_fusion do |v|
      config.vm.define :pebblerunner do |s|
        v.vmx["memsize"] = "2048"
      end
      config.vm.define :pebblerunner do |s|
        v.vmx["displayName"] = "pebblerunner"
      end
    end
end