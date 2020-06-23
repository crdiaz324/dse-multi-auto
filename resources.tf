# Terraform state for this envirionment
terraform {
  required_version = "= 0.11.13"

  backend "s3" {
    encrypt = "false"
    region  = "us-west-2"
    bucket  = "cdtf"
    key     = "terraform/terraform.tfstate"
  }
}

#providers
provider "aws" {
  region = "${var.region}"
}

#resources
resource "aws_vpc" "vpc" {
  cidr_block           = "${var.cidr_vpc}"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags {
    "Environment" = "${var.environment_tag}"
    Name          = "${var.name}"
    Terraform     = "true"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    "Environment" = "${var.environment_tag}"
    Name          = "${var.name}"
    Terraform     = "true"
  }
}

resource "aws_eip" "nat_eip" {
  vpc = true

  tags {
    "Environment" = "${var.environment_tag}"
    Name          = "${var.name}"
    Terraform     = "true"
  }
}

resource "aws_subnet" "subnet_public" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${var.cidr_subnet_public}"
  map_public_ip_on_launch = "true"
  availability_zone       = "${var.availability_zone}"

  tags {
    "Environment" = "${var.environment_tag}"
    Name          = "${var.name}"
    Terraform     = "true"
  }
}

resource "aws_subnet" "subnet_private" {
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "${var.cidr_subnet_private}"
  availability_zone = "${var.availability_zone}"

  tags {
    "Environment" = "${var.environment_tag}"
    Name          = "${var.name}"
    Terraform     = "true"
  }
}

resource "aws_route_table" "rtb_public" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

  tags {
    "Environment" = "${var.environment_tag}"
    Name          = "${var.name}"
    Terraform     = "true"
  }
}

resource "aws_route_table" "rtb_private" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.nat_gw.id}"
  }

  tags {
    "Environment" = "${var.environment_tag}"
    Name          = "${var.name}"
    Terraform     = "true"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = "${aws_eip.nat_eip.id}"
  subnet_id     = "${aws_subnet.subnet_public.id}"

  tags {
    "Environment" = "${var.environment_tag}"
    Name          = "${var.name}"
    Terraform     = "true"
  }
}

resource "aws_route_table_association" "rta_subnet_public" {
  subnet_id      = "${aws_subnet.subnet_public.id}"
  route_table_id = "${aws_route_table.rtb_public.id}"
}

resource "aws_route_table_association" "rta_subnet_private" {
  subnet_id      = "${aws_subnet.subnet_private.id}"
  route_table_id = "${aws_route_table.rtb_private.id}"
}

resource "aws_security_group" "sg_dse" {
  name   = "sg_dse"
  vpc_id = "${aws_vpc.vpc.id}"

  # SSH access from the VPC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    #cidr_blocks = ["${var.cidr_vpc}"]
  }

  # Port 8888 for opscenter access
  ingress {
    from_port   = 8888
    to_port     = 8888
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    #cidr_blocks = ["${var.cidr_vpc}"]
  }

  # Promethius 
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    #cidr_blocks = ["0.0.0.0/0"]
    cidr_blocks = ["${var.cidr_vpc}"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    #cidr_blocks = ["0.0.0.0/0"]
    cidr_blocks = ["${var.cidr_vpc}"]
  }

  ingress {
    from_port   = 9103
    to_port     = 9103
    protocol    = "tcp"
    #cidr_blocks = ["0.0.0.0/0"]
    cidr_blocks = ["${var.cidr_vpc}"]
  }

  # CQL access from the VPC
  ingress {
    from_port   = 9042
    to_port     = 9042
    protocol    = "tcp"
    #cidr_blocks = ["0.0.0.0/0"]
    cidr_blocks = ["${var.cidr_vpc}"]
  }

  # internode communication from the VPC
  ingress {
    from_port   = 7000
    to_port     = 7000
    protocol    = "tcp"
    #cidr_blocks = ["0.0.0.0/0"]
    cidr_blocks = ["${var.cidr_vpc}"]
  }
 
  # jmx communication from VPC
  ingress {
    from_port   = 7199
    to_port     = 7199
    protocol    = "tcp"
    #cidr_blocks = ["0.0.0.0/0"]
    cidr_blocks = ["${var.cidr_vpc}"]
  }

  # opscenterd communication from the VPC
  ingress {
    from_port   = 61620
    to_port     = 61620
    protocol    = "tcp"
    #cidr_blocks = ["0.0.0.0/0"]
    cidr_blocks = ["${var.cidr_vpc}"]
  }

  # opscenter agent communication from the VPC
  ingress {
    from_port   = 61621
    to_port     = 61621
    protocol    = "tcp"
    #cidr_blocks = ["0.0.0.0/0"]
    cidr_blocks = ["${var.cidr_vpc}"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["${var.cidr_vpc}"]
  }

  ingress {
    from_port   = 8609
    to_port     = 8609
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr_vpc}"]
  }


  tags {
    "Environment" = "${var.environment_tag}"
    Name          = "${var.name}"
    Terraform     = "true"
  }
}

resource "aws_key_pair" "ec2key" {
  key_name   = "publicKey"
  public_key = "${file(var.public_key_path)}"
}

resource "aws_instance" "bastion" {
  ami                    = "${var.ami["amazon-linux"]}"
  instance_type          = "${var.instance_type}"
  subnet_id              = "${aws_subnet.subnet_public.id}"
  vpc_security_group_ids = ["${aws_security_group.sg_dse.id}"]
  key_name               = "${aws_key_pair.ec2key.key_name}"

  #lifecycle {
  #  ignore_changes = ["ami", "user_data"]
  #}

  tags {
    "Environment" = "${var.environment_tag}"
    Name          = "${var.name}"
    Terraform     = "true"
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  provisioner "remote-exec" {
    inline = [
      "touch ~/provisioned",
      "echo '${file(var.private_key_path)}' > ~/.ssh/id_rsa",
      "chmod 400 ~/.ssh/id_rsa",
      "echo 'export TERM=xterm-256color' >> ~/.bash_profile",
      "sudo yum install -y java-1.8.0-openjdk.x86_64 git",
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
      "sudo yum install -y opscenter",
      "sudo service opscenterd start",
      "sudo yum update -y",
      "curl https://bintray.com/sbt/rpm/rpm | sudo tee /etc/yum.repos.d/bintray-sbt-rpm.repo",
      "sudo yum install -y sbt",
      "sudo chown ec2-user /var/lib/cassandra/data && ln -snfv /var/lib/cassandra/data data && cd data",
      "git clone https://github.com/crdiaz324/gatling_cassandra_timeslice.git",
      "cd gatling_cassandra_timeslice && git checkout nr-dev && sbt assembly"
    ]
  }
}

module "dse_cluster" {
  #source                 = "github.com/terraform-aws-modules/terraform-aws-ec2-instance.git"
  source  = "modules/ec2-cluster"
  version = "1.12.0"

  name                        = "${var.name}"
  instance_count              = "${var.node_count}"
  associate_public_ip_address = "false"

  ami                    = "${var.ami["amazon-linux"]}"
  instance_type          = "${var.instance_type}"
  key_name               = "${aws_key_pair.ec2key.key_name}"
  monitoring             = false
  vpc_security_group_ids = ["${aws_security_group.sg_dse.id}"]
  subnet_id              = "${aws_subnet.subnet_private.id}"
  private_key_path       = "${var.private_key_path}"
  bastion_host_ip        = "${aws_instance.bastion.public_ip}"

  tags = {
    Terraform = "true"
  }
}

# Bash command to populate /etc/hosts file on each instances
resource "null_resource" "provision_cluster_nodes_hosts_file" {
  count = "${var.node_count}"

  # Changes to any instance of the cluster requires re-provisioning
  triggers {
    cluster_instance_ids = "${join(",", module.dse_cluster.id)}"
  }

  connection {
    type        = "ssh"
    host        = "${element(module.dse_cluster.public_ip, count.index)}"
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  #provisioner "remote-exec" {
  #  inline = [
  #    # Adds all cluster members' IP addresses to /etc/hosts (on each member)
  #    "echo '${join("\n", formatlist("%v ", module.dse_cluster.private_ip))}' | sudo tee -a /etc/hosts > /dev/null",
  #  ]
  #}
}
