module "loadgen" {
  #source                 = "github.com/terraform-aws-modules/terraform-aws-ec2-instance.git"
  source  = "modules/ec2-cluster"
  version = "1.12.0"

  name                        = "loadgen-livenation-tf"
  instance_count              = "4"
  associate_public_ip_address = "false"

  ami                    = "${var.ami["amazon-linux"]}"
  instance_type          = "i3.2xlarge"
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
