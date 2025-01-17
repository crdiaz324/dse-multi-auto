output "vpc_id" {
  value = "${aws_vpc.vpc.id}"
}

output "public_subnets" {
  value = ["${aws_subnet.subnet_public.id}"]
}

output "public_route_table_ids" {
  value = ["${aws_route_table.rtb_public.id}"]
}

output "public_instance_ip" {
  value = ["${aws_instance.bastion.public_ip}"]
}

output "ips_hosts" {
  value = ["${formatlist("%v %v", module.dse_cluster.private_ip, module.dse_cluster.instance_names)}"]
}

output "loadgen_ips" {
  value = ["${formatlist("%v %v", module.loadgen.private_ip, module.loadgen.instance_names)}"]
}
