

provider "aws" {
	access_key = "${var.aws_access_key}"
	secret_key = "${var.aws_secret_key}"
	region = "${var.aws_region}"
}

resource "aws_vpc" "default" {
	cidr_block = "${var.vpc_cidr_block}"
	enable_dns_support = true
	enable_dns_hostnames = true
	tags {
		Name = "${var.application_name}-vpc"
		AppName = "${var.application_name}"
	}
}

resource "aws_internet_gateway" "default" {
	vpc_id = "${aws_vpc.default.id}"
	tags {
		Name = "${var.application_name}-internet-gateway"
		AppName = "${var.application_name}"
	}
}

resource "aws_route" "internet_access" {
	route_table_id = "${aws_vpc.default.main_route_table_id}"
	destination_cidr_block = "0.0.0.0/0"
	gateway_id = "${aws_internet_gateway.default.id}"
}

resource "aws_subnet" "default" {
	vpc_id = "${aws_vpc.default.id}"
	count = "${length(var.aws_azs)}"
	cidr_block = "${element(var.aws_az_cidr_blocks, count.index)}"
	availability_zone = "${element(var.aws_azs, count.index)}"
	map_public_ip_on_launch = true

	tags {
		Name = "${var.application_name}-subnet-${count.index+1}"
		AppName = "${var.application_name}"
	}
}

resource "aws_security_group" "default" {
	name = "${var.application_name}-sg"
	description = "Used for access to all servers via SSH and MongoDB"
	vpc_id = "${aws_vpc.default.id}"

	ingress {
		from_port   = 22
		to_port     = 22
		protocol    = "tcp"
		cidr_blocks = [ "0.0.0.0/0" ]
		description = "SSH access from anywhere"
	}

	ingress {
		from_port   = 27017
		to_port     = 27017
		protocol    = "tcp"
		cidr_blocks = [ "0.0.0.0/0" ]
		description = "MongoDB access from anywhere"
	}

	ingress {
		from_port   = 0
		to_port     = 65535
		protocol    = "tcp"
		self        = true
		description = "MongoDB access from anywhere"
	}

	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = [ "0.0.0.0/0" ]
	}

	tags {
		Name = "${var.application_name}-sg"
		AppName = "${var.application_name}"
	}
}

resource "aws_route53_zone" "default" {
	name = "${var.application_name}.private"
	vpc_id = "${aws_vpc.default.id}"
	tags {
		Name = "${var.application_name}-zone"
		AppName = "${var.application_name}"
	}
}

resource "aws_key_pair" "auth" {
	key_name   = "${var.application_name}-key-pair"
	public_key = "${file(var.public_key_path)}"
}

### [ local variables ] ###########################################################################

locals {
	puppet_ip = "${aws_instance.puppet.0.private_ip}"
}

### [ puppet instance ] ###########################################################################

resource "aws_instance" "puppet" {

	count = 1
	instance_type = "${var.instance_type}"
	ami = "${var.aws_ami}"
	key_name = "${aws_key_pair.auth.id}"
	vpc_security_group_ids = ["${aws_security_group.default.id}"]
	subnet_id = "${element(aws_subnet.default.*.id, count.index)}"

	tags {
		AppName = "${var.application_name}"
		Name = "${var.instance_puppet_name}"
		FQDN = "${format("%s.%s", var.instance_puppet_name, aws_route53_zone.default.name)}"
		Role = "puppet"
	}

	connection {
		type = "ssh"
		user = "ec2-user"
		private_key = "${file(var.private_key_path)}"
	}

	provisioner "file" {
		content = <<EOF
#!/bin/bash
PRIVATE_IP='${self.private_ip}'
PUBLIC_IP='${self.public_ip}'
ROLE='puppet'
SERVER='${var.instance_puppet_name}'
DOMAIN='${aws_route53_zone.default.name}'
FQDN='${format("%s.%s", var.instance_puppet_name, aws_route53_zone.default.name)}'

PUPPET_IP='${self.private_ip}'
CONFIG_NUM='${var.instance_config_num}'
CONFIG_NAME='${var.instance_config_name}'
DATA_NUM='${var.instance_data_num}'
DATA_NAME='${var.instance_data_name}'
ROUTER_NUM='${var.instance_router_num}'
ROUTER_NAME='${var.instance_router_name}'

declare -A REPLSET_MAPPING
REPLSET_MAPPING=( ${join(" ", formatlist("[%s]=\"%s\"", keys(var.replset_mapping), values(var.replset_mapping)))} )

declare -A INSTANCE_MAPPING
INSTANCE_MAPPING=( ${join(" ", formatlist("[%s]=\"%s\"", keys(var.instance_mapping), values(var.instance_mapping)))} )

declare -A ROUTER_MAPPING
ROUTER_MAPPING=( ${join(" ", formatlist("[%s]=\"%s\"", keys(var.router_mapping), values(var.router_mapping)))} )
EOF
		destination = "./config"
	}

	provisioner "file" {
		source = "bootstrap.sh"
		destination = "./bootstrap.sh"
	}

	provisioner "file" {
		source = "functions.sh"
		destination = "./functions.sh"
	}

	provisioner "remote-exec" {
		inline = [
			"sudo bash ./bootstrap.sh",
		]
	}
}

resource "aws_route53_record" "puppet" {
	count = 1
	zone_id = "${aws_route53_zone.default.zone_id}"
	name = "${var.instance_puppet_name}"
	type = "A"
	ttl = "300"
	records = [ "${aws_instance.puppet.0.private_ip}" ]
}


### [ config instances ] ##########################################################################

resource "aws_instance" "config" {

	count = "${var.instance_config_num}"
	instance_type = "${var.instance_type}"
	ami = "${var.aws_ami}"
	key_name = "${aws_key_pair.auth.id}"
	vpc_security_group_ids = ["${aws_security_group.default.id}"]
	subnet_id = "${element(aws_subnet.default.*.id, count.index)}"
	depends_on = ["aws_instance.puppet"]

	tags {
		AppName = "${var.application_name}"
		Name = "${format("%s-%d", var.instance_config_name, count.index+1)}"
		FQDN = "${format("%s-%d.%s", var.instance_config_name, count.index+1, aws_route53_zone.default.name)}"
		Role = "config"
	}

	connection {
		type = "ssh"
		user = "ec2-user"
		private_key = "${file(var.private_key_path)}"
	}

	provisioner "file" {
		content = <<EOF
PRIVATE_IP='${self.private_ip}'
PUBLIC_IP='${self.public_ip}'
ROLE='config'
SERVER=${format("%s-%d", var.instance_config_name, count.index+1)}
DOMAIN='${aws_route53_zone.default.name}'
FQDN=${format("%s-%d.%s", var.instance_config_name, count.index+1, aws_route53_zone.default.name)}

PUPPET_IP='${local.puppet_ip}'
EOF
		destination = "./config"
	}

	provisioner "file" {
		source = "bootstrap.sh"
		destination = "./bootstrap.sh"
	}

	provisioner "remote-exec" {
		inline = [
			"sudo bash ./bootstrap.sh",
		]
	}
}

resource "aws_route53_record" "config" {
	count = "${var.instance_config_num}"
	zone_id = "${aws_route53_zone.default.zone_id}"
	name = "${format("%s-%d", var.instance_config_name, count.index+1)}"
	type = "A"
	ttl = "300"
	records = [ "${element(aws_instance.config.*.private_ip, count.index)}" ]
}

### [ data instances ] ############################################################################

resource "aws_instance" "data" {

	count = "${var.instance_data_num}"
	instance_type = "${var.instance_type}"
	ami = "${var.aws_ami}"
	key_name = "${aws_key_pair.auth.id}"
	vpc_security_group_ids = ["${aws_security_group.default.id}"]
	subnet_id = "${element(aws_subnet.default.*.id, count.index)}"
	depends_on = ["aws_instance.puppet"]

	tags {
		AppName = "${var.application_name}"
		Name = "${format("%s-%d", var.instance_data_name, count.index+1)}"
		FQDN = "${format("%s-%d.%s", var.instance_data_name, count.index+1, aws_route53_zone.default.name)}"
		Role = "data"
	}

	connection {
		type = "ssh"
		user = "ec2-user"
		private_key = "${file(var.private_key_path)}"
	}

	provisioner "file" {
		content = <<EOF
PRIVATE_IP='${self.private_ip}'
PUBLIC_IP='${self.public_ip}'
ROLE='data'
SERVER=${format("%s-%d", var.instance_data_name, count.index+1)}
DOMAIN='${aws_route53_zone.default.name}'
FQDN=${format("%s-%d.%s", var.instance_data_name, count.index+1, aws_route53_zone.default.name)}

PUPPET_IP='${local.puppet_ip}'
EOF
		destination = "./config"
	}

	provisioner "file" {
		source = "bootstrap.sh"
		destination = "./bootstrap.sh"
	}

	provisioner "remote-exec" {
		inline = [
			"sudo bash ./bootstrap.sh",
		]
	}
}

resource "aws_route53_record" "data" {
	count = "${var.instance_data_num}"
	zone_id = "${aws_route53_zone.default.zone_id}"
	name = "${format("%s-%d", var.instance_data_name, count.index+1)}"
	type = "A"
	ttl = "300"
	records = [ "${element(aws_instance.data.*.private_ip, count.index)}" ]
}

### [ router instances ] ##########################################################################

resource "aws_instance" "router" {

	count = "${var.instance_router_num}"
	instance_type = "${var.instance_type}"
	ami = "${var.aws_ami}"
	key_name = "${aws_key_pair.auth.id}"
	vpc_security_group_ids = ["${aws_security_group.default.id}"]
	subnet_id = "${element(aws_subnet.default.*.id, count.index)}"
	depends_on = ["aws_instance.config", "aws_instance.data"]

	tags {
		AppName = "${var.application_name}"
		Name = "${format("%s-%d", var.instance_router_name, count.index+1)}"
		FQDN = "${format("%s-%d.%s", var.instance_router_name, count.index+1, aws_route53_zone.default.name)}"
		Role = "router"
	}

	connection {
		type = "ssh"
		user = "ec2-user"
		private_key = "${file(var.private_key_path)}"
	}

	provisioner "file" {
		content = <<EOF
PRIVATE_IP='${self.private_ip}'
PUBLIC_IP='${self.public_ip}'
ROLE='router'
SERVER=${format("%s-%d", var.instance_router_name, count.index+1)}
DOMAIN='${aws_route53_zone.default.name}'
FQDN=${format("%s-%d.%s", var.instance_router_name, count.index+1, aws_route53_zone.default.name)}

PUPPET_IP='${local.puppet_ip}'
EOF
		destination = "./config"
	}

	provisioner "file" {
		source = "bootstrap.sh"
		destination = "./bootstrap.sh"
	}

	provisioner "remote-exec" {
		inline = [
			"sudo bash ./bootstrap.sh",
		]
	}
}

resource "aws_route53_record" "router" {
	count = "${var.instance_router_num}"
	zone_id = "${aws_route53_zone.default.zone_id}"
	name = "${format("%s-%d", var.instance_router_name, count.index+1)}"
	type = "A"
	ttl = "300"
	records = [ "${element(aws_instance.router.*.private_ip, count.index)}" ]
}
