#################################################
# The variables below should be customized for 
# your particular needs
#################################################

variable "region" {
  default = "us-west-1"
}

variable "availability_zone" {
  description = "availability zone to create subnet"
  default     = "us-west-1a"
}

#################################################
# In my case I created a key for my aws hosts.
# The following key will be used to log in to
# the bastion host and the private key will
# also be uploaded to all the nodes to allow
# use to login to/from all nodes.
#################################################

variable "public_key_path" {
  description = "Public key path"
  default     = "~/.ssh/datastax_aws.rsa.pub"
}

variable "private_key_path" {
  description = "Private key path"
  default     = "~/.ssh/datastax_aws.rsa"
}

variable "environment_tag" {
  description = "Environment tag"
  default     = "Dev"
}

variable "name" {
  default     = "livenation-tf"
  description = "The name for this deployment"
}

variable "node_count" {
  description = "Number of nodes in the cluster"
  default     = "6"
}

#####################################
#
# DO NOT MODIFY THE SECTION BELOW
# UNLESS YOU HAVE A REASON TO.
#
#####################################

variable "cidr_vpc" {
  description = "CIDR block for the VPC"
  default     = "10.1.0.0/16"
}

variable "cidr_subnet_public" {
  description = "CIDR block for the subnet"
  default     = "10.1.0.0/24"
}

variable "cidr_subnet_private" {
  description = "CIDR block for the subnet"
  default     = "10.1.100.0/24"
}

variable "ami" {
  default = {
    "ubuntu-18.04" = "ami-06397100adf427136"
    "amazon-linux" = "ami-0019ef04ac50be30f"
    "rhel-8"       = "ami-08949fb6466dd2cf3"
  }

  description = "map of AMIs to use"
}

variable "instance_type" {
  default = {
    "test-instance" = "t2.micro"
    "m4-2xlarge"    = "m4.2xlarge"
    "m4-4xlarge"    = "m4.4xlarge"
    "i3-xlarge"     = "i3.xlarge"
    "i3-2xlarge"    = "i3.2xlarge"
  }

  description = "map of instance types to use"
}

