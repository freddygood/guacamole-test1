
variable "aws_access_key" {
	description = "AWS access key"
}

variable "aws_secret_key" {
	description = "AWS secret key"
}

variable "application_name" {
	description = "Application name, actually used for tag and resource naming"
	default = "guacamole"
}

# ssh keys

variable "public_key_path" {
	description = "Path to the SSH public key to be used for authentication"
	default = "mongodb-test-key.pub"
}

variable "private_key_path" {
	description = "Path to the SSH private key to be used for authentication"
	default = "mongodb-test-key"
}

# vpc and security

variable "vpc_cidr_block" {
	description = "VPC for application"
	default = "10.0.0.0/16"
}

variable "aws_region" {
	description = "AWS region to launch nodes"
	default = "us-west-1"
}

variable "aws_azs" {
	description = "AWS AZ ot server launch, must be in selected region"
	default = [ "us-west-1a", "us-west-1c" ]
}

variable "aws_az_cidr_blocks" {
	description = "Networks for selected AZ"
	default = [ "10.0.0.0/24", "10.0.1.0/24" ]
}

variable "aws_ami" {
	description = "API for instances launch, Amazon Linux currently"
	default = "ami-a51f27c5"
}

variable "instance_type" {
	description = "Size of EC2 instance"
	default = "t2.micro"
}

# instance mapping

variable "instance_puppet_name" {
	description = "Name of puppet instance, used for instance naming and DNS records"
	default = "mongodb-puppet"
}

variable "instance_config_num" {
	description = "Number of config instances"
	default = 3
}

variable "instance_config_name" {
	description = "Name of config instances, used for instance naming and DNS records"
	default = "mongodb-config"
}

variable "instance_data_num" {
	description = "Number of data instances"
	default = 6
}

variable "instance_data_name" {
	description = "Name of data instances, used for instance naming and DNS records"
	default = "mongodb-data"
}

variable "instance_router_num" {
	description = "Number of router instances"
	default = 2
}

variable "instance_router_name" {
	description = "Name of router instances, used for instance naming and DNS records"
	default = "mongodb-router"
}

variable "replset_mapping" {
	description = "Mapping of all replica sets in application, format [replica_set_name => instance_list]"
	default = {
		"guacamole-config" = "mongodb-config-1 mongodb-config-2 mongodb-config-3"
		"guacamole-data-1" = "mongodb-data-1 mongodb-data-2 mongodb-data-3"
		"guacamole-data-2" = "mongodb-data-4 mongodb-data-5 mongodb-data-6"
	}
}

variable "instance_mapping" {
	description = "Mapping of all instances and replica sets in application, format [instance => replica_set]"
	default = {
		"mongodb-config-1" = "guacamole-config"
		"mongodb-config-2" = "guacamole-config"
		"mongodb-config-3" = "guacamole-config"
		"mongodb-data-1" = "guacamole-data-1"
		"mongodb-data-2" = "guacamole-data-1"
		"mongodb-data-3" = "guacamole-data-1"
		"mongodb-data-4" = "guacamole-data-2"
		"mongodb-data-5" = "guacamole-data-2"
		"mongodb-data-6" = "guacamole-data-2"
	}
}

variable "router_mapping" {
	description = "Mapping of router instances, format [meaning (config or data) => replica_set_list]"
	default = {
		"config" = "guacamole-config"
		"data" = "guacamole-data-1 guacamole-data-2"
	}
}

