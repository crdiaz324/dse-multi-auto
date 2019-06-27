locals {
  is_t_instance_type = "${replace(var.instance_type, "/^t[23]{1}\\..*$/", "1") == "1" ? "1" : "0"}"
}

######
# Note: network_interface can't be specified together with associate_public_ip_address
######
resource "aws_instance" "this" {
  count = "${var.instance_count * (1 - local.is_t_instance_type)}"

  ami                    = "${var.ami}"
  instance_type          = "${var.instance_type}"
  user_data              = "${var.user_data}"
  subnet_id              = "${element(distinct(compact(concat(list(var.subnet_id), var.subnet_ids))),count.index)}"
  key_name               = "${var.key_name}"
  monitoring             = "${var.monitoring}"
  vpc_security_group_ids = ["${var.vpc_security_group_ids}"]
  iam_instance_profile   = "${var.iam_instance_profile}"

  associate_public_ip_address = "${var.associate_public_ip_address}"
  private_ip                  = "${var.private_ip}"
  ipv6_address_count          = "${var.ipv6_address_count}"
  ipv6_addresses              = "${var.ipv6_addresses}"

  ebs_optimized          = "${var.ebs_optimized}"
  volume_tags            = "${var.volume_tags}"
  root_block_device      = "${var.root_block_device}"
  ebs_block_device       = "${var.ebs_block_device}"
  ephemeral_block_device = "${var.ephemeral_block_device}"

  source_dest_check                    = "${var.source_dest_check}"
  disable_api_termination              = "${var.disable_api_termination}"
  instance_initiated_shutdown_behavior = "${var.instance_initiated_shutdown_behavior}"
  placement_group                      = "${var.placement_group}"
  tenancy                              = "${var.tenancy}"

  tags = "${merge(map("Name", (var.instance_count > 1) || (var.use_num_suffix == "true") ? format("%s-%d", var.name, count.index+1) : var.name), var.tags)}"

  lifecycle {
    # Due to several known issues in Terraform AWS provider related to arguments of aws_instance:
    # (eg, https://github.com/terraform-providers/terraform-provider-aws/issues/2036)
    # we have to ignore changes in the following arguments
    ignore_changes = ["private_ip", "root_block_device", "ebs_block_device"]
  }

  connection {
    type             = "ssh"
    user             = "ec2-user"
    private_key      = "${file(var.private_key_path)}"
    bastion_host     = "${var.bastion_host_ip}"
    bastion_user     = "ec2-user"
    bastion_host_key = "${file(var.private_key_path)}"
  }

  provisioner "remote-exec" {
    inline = [
      "touch ~/provisioned",
      "echo '${file(var.private_key_path)}' > ~/.ssh/id_rsa",
      "chmod 400 ~/.ssh/id_rsa",
      "echo 'export TERM=xterm-256color' >> ~/.bash_profile",
      "sudo yum install -y java-1.8.0-openjdk.x86_64",
      "for CPUFREQ in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do     [ -f $CPUFREQ ] || continue;     echo -n performance > $CPUFREQ; done",
      "sudo parted -a optimal -s /dev/nvme0n1 mklabel gpt mkpart Data 'xfs' '0%' '100%'",
      "sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm",
      "sudo yum-config-manager --enable epel",
      "sudo yum erase -y 'ntp*'",
      "sudo yum install -y chrony",
      "sudo service chronyd start",
      "sudo chkconfig chronyd on",
      "echo 'net.ipv4.tcp_keepalive_time=60' |sudo tee -a /etc/sysctl.conf",
      "echo 'net.ipv4.tcp_keepalive_probes=3' |sudo tee -a /etc/sysctl.conf",
      "echo 'net.ipv4.tcp_keepalive_intvl=10' |sudo tee -a /etc/sysctl.conf",
      "echo 'net.core.rmem_max=16777216'|sudo tee -a /etc/sysctl.conf",
      "echo 'net.core.wmem_max=16777216' |sudo tee -a /etc/sysctl.conf",
      "echo 'net.core.rmem_default=16777216' |sudo tee -a /etc/sysctl.conf",
      "echo 'net.core.wmem_default=16777216' |sudo tee -a /etc/sysctl.conf",
      "echo 'net.core.optmem_max=40960' |sudo tee -a /etc/sysctl.conf",
      "echo 'net.ipv4.tcp_rmem=4096 87380 16777216' |sudo tee -a /etc/sysctl.conf",
      "echo 'net.ipv4.tcp_wmem=4096 65536 16777216'  |sudo tee -a /etc/sysctl.conf",
      "echo 'vm.max_map_count = 1048575'  |sudo tee -a /etc/sysctl.conf",
      "echo 'vm.dirty_background_bytes = 10485760'  |sudo tee -a /etc/sysctl.conf",
      "echo 'vm.dirty_bytes = 1073741824'  |sudo tee -a /etc/sysctl.conf",
      "echo 'vm.zone_reclaim_mode = 0'  |sudo tee -a /etc/sysctl.conf",
      "sudo sysctl -p",
      "sudo mkfs.xfs -f /dev/nvme0n1p1",
      "sudo mkdir -p /var/lib/cassandra/data",
      "echo '/dev/nvme0n1p1 /var/lib/cassandra/data xfs defaults,noatime 1 1' |sudo tee -a /etc/fstab",
      "sudo mount -a",
      "echo 'cassandra - memlock unlimited' | sudo tee -a /etc/security/limits.d/cassandra.conf",
      "echo 'cassandra - nofile 1048576' | sudo tee -a /etc/security/limits.d/cassandra.conf",
      "echo 'cassandra - nproc 32768' | sudo tee -a /etc/security/limits.d/cassandra.conf",
      "echo 'cassandra - as unlimited' | sudo tee -a /etc/security/limits.d/cassandra.conf",
      "echo never | sudo tee -a /sys/kernel/mm/transparent_hugepage/defrag",
      "echo 'sudo blockdev --setra 8 /dev/nvme0n1' | sudo tee -a /etc/rc.local",
      "sudo chmod +x /etc/rc.local",
      "sudo yum install -y libaio",
      "echo '[datastax]' |sudo tee -a /etc/yum.repos.d/datastax.repo",
      "echo 'name=DataStax Repo for DataStax Enterprise' | sudo tee -a /etc/yum.repos.d/datastax.repo",
      "echo 'baseurl=https://rpm.datastax.com/enterprise/' | sudo tee -a /etc/yum.repos.d/datastax.repo",
      "echo 'enabled=1' | sudo tee -a /etc/yum.repos.d/datastax.repo",
      "echo 'gpgcheck=0' | sudo tee -a /etc/yum.repos.d/datastax.repo",
      "sudo rpm --import https://rpm.datastax.com/rpm/repo_key",
      "sudo yum install -y dse-full",
      "sudo chown -R cassandra:cassandra /var/lib/cassandra",
      "sudo yum update -y"
    ]
  }
}

resource "aws_instance" "this_t2" {
  count = "${var.instance_count * local.is_t_instance_type}"

  ami                    = "${var.ami}"
  instance_type          = "${var.instance_type}"
  user_data              = "${var.user_data}"
  subnet_id              = "${element(distinct(compact(concat(list(var.subnet_id), var.subnet_ids))),count.index)}"
  key_name               = "${var.key_name}"
  monitoring             = "${var.monitoring}"
  vpc_security_group_ids = ["${var.vpc_security_group_ids}"]
  iam_instance_profile   = "${var.iam_instance_profile}"

  associate_public_ip_address = "${var.associate_public_ip_address}"
  private_ip                  = "${var.private_ip}"
  ipv6_address_count          = "${var.ipv6_address_count}"
  ipv6_addresses              = "${var.ipv6_addresses}"

  ebs_optimized          = "${var.ebs_optimized}"
  volume_tags            = "${var.volume_tags}"
  root_block_device      = "${var.root_block_device}"
  ebs_block_device       = "${var.ebs_block_device}"
  ephemeral_block_device = "${var.ephemeral_block_device}"

  source_dest_check                    = "${var.source_dest_check}"
  disable_api_termination              = "${var.disable_api_termination}"
  instance_initiated_shutdown_behavior = "${var.instance_initiated_shutdown_behavior}"
  placement_group                      = "${var.placement_group}"
  tenancy                              = "${var.tenancy}"

  credit_specification {
    cpu_credits = "${var.cpu_credits}"
  }

  tags = "${merge(map("Name", (var.instance_count > 1) || (var.use_num_suffix == "true") ? format("%s-%d", var.name, count.index+1) : var.name), var.tags)}"

  lifecycle {
    # Due to several known issues in Terraform AWS provider related to arguments of aws_instance:
    # (eg, https://github.com/terraform-providers/terraform-provider-aws/issues/2036)
    # we have to ignore changes in the following arguments
    ignore_changes = ["private_ip", "root_block_device", "ebs_block_device"]
  }

  connection {
    type             = "ssh"
    user             = "ec2-user"
    private_key      = "${file(var.private_key_path)}"
    bastion_host     = "${var.bastion_host_ip}"
    bastion_user     = "ec2-user"
    bastion_host_key = "${file(var.private_key_path)}"
  }

  provisioner "remote-exec" {
    inline = [
      "touch ~/provisioned",
      "echo '${file(var.private_key_path)}' > ~/.ssh/id_rsa",
      "chmod 400 ~/.ssh/id_rsa",
      "echo 'export TERM=xterm-256color' >> ~/.bash_profile",
      "for CPUFREQ in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do     [ -f $CPUFREQ ] || continue;     echo -n performance > $CPUFREQ; done",
      "sudo parted -a optimal -s /dev/nvme0n1 mklabel gpt mkpart Data 'xfs' '0%' '100%'",
      "sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm",
      "sudo yum-config-manager --enable epel",
      "sudo yum erase -y 'ntp*'",
      "sudo yum install -y chrony",
      "sudo service chronyd start",
      "sudo chkconfig chronyd on",
      "echo 'net.ipv4.tcp_keepalive_time=60' |sudo tee -a /etc/sysctl.conf",
      "echo 'net.ipv4.tcp_keepalive_probes=3' |sudo tee -a /etc/sysctl.conf",
      "echo 'net.ipv4.tcp_keepalive_intvl=10' |sudo tee -a /etc/sysctl.conf",
      "echo 'net.core.rmem_max=16777216'|sudo tee -a /etc/sysctl.conf",
      "echo 'net.core.wmem_max=16777216' |sudo tee -a /etc/sysctl.conf",
      "echo 'net.core.rmem_default=16777216' |sudo tee -a /etc/sysctl.conf",
      "echo 'net.core.wmem_default=16777216' |sudo tee -a /etc/sysctl.conf",
      "echo 'net.core.optmem_max=40960' |sudo tee -a /etc/sysctl.conf",
      "echo 'net.ipv4.tcp_rmem=4096 87380 16777216' |sudo tee -a /etc/sysctl.conf",
      "echo 'net.ipv4.tcp_wmem=4096 65536 16777216'  |sudo tee -a /etc/sysctl.conf",
      "sudo sysctl -p",
      "sudo mkfs.xfs -f /dev/nvme0n1p1",
      "sudo mkdir -p /var/lib/cassandra/data",
      "sudo chown -R cassandra:cassandra /var/lib/cassandra",
      "echo '/dev/nvme0n1p1 /var/lib/cassandra/data xfs defaults,noatime 1 1' |sudo tee -a /etc/fstab",
      "sudo mount -a"
    ]
  }
}
