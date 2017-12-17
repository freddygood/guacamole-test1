#!/bin/bash

ROLE=$1
HOST=$2
PUPPET_IP=$3

REPO='https://github.com/freddygood/guacamole-test1.git'
REPO_DIR='/tmp/guacamole-test1'

# update packages
yum -y update

# setting hostname
hostname $HOST

# update /etc/hosts with puppet master server
if grep -qE "^.*[:blank:]puppet$" /etc/hosts; then
	sed -i.bak -E "s/^.*[:blank:]puppet$/${PUPPET_IP} puppet/1" /etc/hosts
else
	echo -e "\n${PUPPET_IP} puppet" >> /etc/hosts
fi

# install basic packages
yum -y install git tcpdump

# getting configuration repo
git clone $REPO $REPO_DIR

case $ROLE in
	'puppet')
		yum -y install puppet3-server
		chkconfig puppetmaster on
		puppet module install puppet-mongodb
		cp $REPO_DIR/puppet-master/autosign.conf /etc/puppet/
		;;
	*)
		# getting pupet agent
		yum -y install puppet3
		chkconfig puppet on
		;;
esac
