#!/bin/bash

function create_hiera_yaml() {
	cat <<EOF > /etc/puppet/hiera.yaml
---
:hierarchy:
    - "nodes/%{::hostname}"
    - global
:backends:
    - yaml
:yaml:
    :datadir: '/etc/puppet/hieradata'
EOF
}

function create_global_yaml() {
	local CONFIG_REPLSET=${ROUTER_MAPPING['config']}
	local CONFIG_LIST=${REPLSET_MAPPING[$CONFIG_REPLSET]}
	local CONFIGDB=$(for S in ${CONFIG_LIST}; do echo -n "$S:27019,"; done | sed 's/,$//1')
	cat <<EOF > /etc/puppet/hieradata/global.yaml
---
mongodb::globals::manage_package_repo: true
mongodb::globals::repo_location: 'http://repo.mongodb.org/yum/amazon/2013.03/mongodb-org/3.4/x86_64/'

mongodb::server::smallfiles: true
mongodb::server::manage_pidfile: false
mongodb::server::bind_ip:
  - '0.0.0.0'
mongodb::server::verbose: true

mongodb::mongos::configdb:
  - '$CONFIG_REPLSET/$CONFIGDB'
EOF
}

function create_site_pp() {
	cat <<EOF > /etc/puppet/manifests/site.pp

node mongodb-puppet {
  class { 'mongodb::globals': } ->
  class { 'mongodb::client': }
}

node /^mongodb-config-/ {
  class { 'mongodb::globals': } ->
  class { 'mongodb::server': } ->
  class { 'mongodb::client': }
}

node /^mongodb-data-/ {
  class { 'mongodb::globals': } ->
  class { 'mongodb::server': } ->
  class { 'mongodb::client': }
}

node /^mongodb-router-/ {
  class { 'mongodb::globals': } ->
  class { 'mongodb::server': } ->
  class { 'mongodb::client': } ->
  class { 'mongodb::mongos': }
EOF

	local R I DATA_REPLSET_LIST=${ROUTER_MAPPING['data']}
	for R in $DATA_REPLSET_LIST; do
		I=$(echo ${REPLSET_MAPPING[$R]} | awk '{print $1}')
		cat <<EOF >> /etc/puppet/manifests/site.pp
  -> exec { 'adding shard $R/$I:27018':
    path => $::path,
    command => "mongo --quiet --eval 'sh.addShard(\"$R/$I:27018\")'",
    unless => "mongo --quiet --eval 'db.getSiblingDB(\"admin\").runCommand( { listShards: 1 } )' | jq -r '.shards[]._id' | grep -xq '$R'",
  }
EOF
	done

	cat <<EOF >> /etc/puppet/manifests/site.pp
}
EOF
}

function create_nodes_config_pp() {
	local N INSTANCE REPLSET REPLSET_LIST REPLSET_INIT_INSTANCE
	for N in `seq $CONFIG_NUM`; do
		INSTANCE=$CONFIG_NAME-$N
		REPLSET=${INSTANCE_MAPPING[$INSTANCE]}
		REPLSET_LIST=${REPLSET_MAPPING[$REPLSET]}
		REPLSET_INIT_INSTANCE=$(echo $REPLSET_LIST | awk '{print $1}')
		cat <<EOF > /etc/puppet/hieradata/nodes/$INSTANCE.yaml
---
mongodb::server::configsvr: true
mongodb::server::replset: '$REPLSET'
EOF
		if [ $INSTANCE == $REPLSET_INIT_INSTANCE ]; then
			cat <<EOF >> /etc/puppet/hieradata/nodes/$INSTANCE.yaml
mongodb::server::replset_members:
$(for S in ${REPLSET_LIST}; do echo "  - '$S:27019'"; done)
EOF
		fi
	done
}

function create_nodes_data_pp() {
	local N INSTANCE REPLSET REPLSET_LIST REPLSET_INIT_INSTANCE
	for N in `seq $DATA_NUM`; do
		INSTANCE=$DATA_NAME-$N
		REPLSET=${INSTANCE_MAPPING[$INSTANCE]}
		REPLSET_LIST=${REPLSET_MAPPING[$REPLSET]}
		REPLSET_INIT_INSTANCE=$(echo $REPLSET_LIST | awk '{print $1}')
		cat <<EOF > /etc/puppet/hieradata/nodes/$INSTANCE.yaml
---
mongodb::server::shardsvr: true
mongodb::server::replset: '$REPLSET'
EOF
		if [ $INSTANCE == $REPLSET_INIT_INSTANCE ]; then
			cat <<EOF >> /etc/puppet/hieradata/nodes/$INSTANCE.yaml
mongodb::server::replset_members:
$(for S in ${REPLSET_LIST}; do echo "  - '$S:27018'"; done)
EOF
		fi
	done
}

function create_nodes_router_pp() {
	local INSTANCE
	for N in `seq $ROUTER_NUM`; do
		INSTANCE=$ROUTER_NAME-$N
		cat <<EOF > /etc/puppet/hieradata/nodes/$INSTANCE.yaml
---
mongodb::server::service_ensure: absent
EOF
	done
}
