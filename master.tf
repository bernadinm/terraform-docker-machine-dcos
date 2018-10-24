resource "dockermachine_virtualbox" "master" {
    count = "${var.num_of_masters}"
    name = "master-${count.index}"
    virtualbox_cpu_count = 1
    virtualbox_memory = 3072
    #virtualbox_boot2docker_url = "https://stable.release.core-os.net/amd64-usr/current/coreos_production_iso_image.iso"
    provisioner "remote-exec" {
        inline = [
            "tce-load -wic bash.tcz",
            "tce-load -wic xz.tcz",
            "tce-load -wic git.tcz",
            "tce-load -wic ncurses-utils.tcz",
            "tce-load -wic ipset-dev.tcz",
            "tce-load -wic glibc_apps.tcz",
            "sudo ln -s /usr/local/bin/curl /usr/bin/curl"
        ]
        connection {
            type        = "ssh"
            host        = "${self.ssh_hostname}"
            port        = "${self.ssh_port}"
            user        = "${self.ssh_username}"
            private_key = "${file("${self.ssh_keypath}")}"
        }
    }
}

# Create DCOS Mesos Master Scripts to execute
module "dcos-mesos-master" {
  source               = "github.com/dcos/tf_dcos_core"
  bootstrap_private_ip = "${dockermachine_virtualbox.bootstrap.address}"
  dcos_bootstrap_port  = "${var.custom_dcos_bootstrap_port}"
  # Only allow upgrade and install as installation mode
  dcos_install_mode = "${var.state == "upgrade" ? "upgrade" : "install"}"
  dcos_version         = "${var.dcos_version}"
  role                 = "dcos-mesos-master"
}

resource "null_resource" "master" {
  # If state is set to none do not install DC/OS
  count = "${var.state == "none" ? 0 : var.num_of_masters}"
  # Changes to any instance of the cluster requires re-provisioning
  triggers {
    cluster_instance_ids = "${null_resource.bootstrap.id}"
    current_ec2_instance_id = "${element(dockermachine_virtualbox.master.*.id, count.index)}"
  }
  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  connection {
    type        = "ssh"
    host        = "${element(dockermachine_virtualbox.master.*.ssh_hostname, count.index)}"
    port        = "${element(dockermachine_virtualbox.master.*.ssh_port, count.index)}"
    user        = "${element(dockermachine_virtualbox.master.*.ssh_username, count.index)}"
    private_key = "${file("${element(dockermachine_virtualbox.master.*.ssh_keypath, count.index)}")}"
   }

  count = "${var.num_of_masters}"

  # Generate and upload Master script to node
  provisioner "file" {
    content     = "${module.dcos-mesos-master.script}"
    destination = "run.sh"
  }

  # Wait for bootstrapnode to be ready
  provisioner "remote-exec" {
    inline = [
     "until $(curl --output /dev/null --silent --head --fail http://${dockermachine_virtualbox.bootstrap.address}:${var.custom_dcos_bootstrap_port}/dcos_install.sh); do printf 'waiting for bootstrap node to serve...'; sleep 20; done"
    ]
  }

  # Install Master Script
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x run.sh",
      "sudo ./run.sh",
    ]
  }

  # Watch Master Nodes Start
  provisioner "remote-exec" {
    inline = [
      "until $(curl --output /dev/null --silent --head --fail http://${element(dockermachine_virtualbox.master.*.address, count.index)}/); do printf 'loading DC/OS...'; sleep 10; done"
    ]
  }
}
