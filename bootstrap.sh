#!/bin/bash

echo "Got configuration"
cat $(dirname $0)/config

. $(dirname $0)/config

hostname -v $FQDN

sed -i.bak -E "s/^(HOSTNAME=.*)$/HOSTNAME=${FQDN}/1" /etc/sysconfig/network

cat <<EOF >> /etc/hosts

# reference to private ips
$PRIVATE_IP $SERVER
$PRIVATE_IP $FQDN

# reference to puppet master
$PUPPET_IP puppet
EOF

service network restart

yum -y -d1 install telnet tcpdump jq

yum -y -d1 update

if [ $ROLE == 'puppet' ]; then

	yum -y -d1 install puppet3 puppet3-server

	grep -q ^\\[master\\] /etc/puppet/puppet.conf || echo -e "\n[master]" >> /etc/puppet/puppet.conf
	grep -q autosign /etc/puppet/puppet.conf || echo -e "    autosign = true" >> /etc/puppet/puppet.conf
	puppet module install puppet-mongodb --version 1.1.0

	mkdir -p /etc/puppet/hieradata/nodes

	. $(dirname $0)/functions.sh

	create_hiera_yaml
	create_global_yaml
	create_site_pp

	create_nodes_config_pp
	create_nodes_data_pp
	create_nodes_router_pp

	chkconfig puppetmaster on
	service puppetmaster start
	chkconfig puppet on
	service puppet start

else

	yum -y -d1 install puppet3
	chkconfig puppet on
	puppet agent --test
	# service puppet start

fi
