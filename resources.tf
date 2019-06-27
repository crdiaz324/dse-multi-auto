# Terraform state for this envirionment
terraform {
  required_version = "= 0.11.13"

  backend "s3" {
    encrypt = "false"
    region  = "us-west-1"
    bucket  = "cdiaz-livenation"
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
  }

  # Port 8888 for opscenter access
  ingress {
    from_port   = 8888
    to_port     = 8888
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Promethius 
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9103
    to_port     = 9103
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # CQL access from the VPC
  ingress {
    from_port   = 9042
    to_port     = 9042
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr_vpc}"]
  }

  # internode communication from the VPC
  ingress {
    from_port   = 7000
    to_port     = 7000
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr_vpc}"]
  }

  # opscenterd communication from the VPC
  ingress {
    from_port   = 61620
    to_port     = 61620
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr_vpc}"]
  }

  # opscenter agent communication from the VPC
  ingress {
    from_port   = 61621
    to_port     = 61621
    protocol    = "tcp"
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
  instance_type          = "${var.instance_type["i3-xlarge"]}"
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
  instance_type          = "${var.instance_type["i3-xlarge"]}"
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
