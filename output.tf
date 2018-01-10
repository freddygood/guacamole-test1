
output "mongodb-puppet-ips" {
	description = "Public IP of puppet server"
	value = ["${aws_instance.puppet.public_ip}"]
}

output "mongodb-config-ips" {
	description = "Public IP of configuration cluster"
	depends_on = ["mongodb-puppet-ips"]
	value = ["${aws_instance.config.*.public_ip}"]
}

output "mongodb-data-ips" {
	description = "Public IP of data cluster"
	depends_on = ["mongodb-puppet-ips"]
	value = ["${aws_instance.data.*.public_ip}"]
}

output "mongodb-router-ips" {
	description = "Public IP of router cluster"
	depends_on = ["mongodb-puppet-ips"]
	value = ["${aws_instance.router.*.public_ip}"]
}
