require 'vagrant'

Vagrant::Config.run do |vagrant|

  vagrant.vm.define "centos" do |centos|
    centos.vm.boot_mode = :headless
    centos.vm.box = "centos-6.4.x86_64"
    centos.vm.box_url = "/srv/boxes/centos-6.4.x86_64.box"
    centos.vm.host_name = "tc-vagrant01"
    centos.vm.forward_port 22, rand(2222..2999), {:auto => true}
    centos.vm.network :hostonly, "10.3.16.2"
    centos.ssh.timeout = 120
    #centos.vbguest.auto_update = false
  end
end
