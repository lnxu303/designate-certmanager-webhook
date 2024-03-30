#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

NET_INF=$(ip route get 1|awk '{print $5;exit}')
ADVERTISE_ADDRESS=$(ip addr show ${NET_INF} | grep "inet\s" | tr '/' ' ' | awk '{print $2}')
NAMED_ADDRESS=$(dig +short ${NAMED_HOSTNAME})

mkdir -p /etc/designate

if [ -n "${RNDC_KEY_B64}" ]; then
	echo -n "${RNDC_KEY_B64}" | base64 -d > /etc/designate/rndc.key
fi

cat > /usr/local/bin/configure-designate <<EOF
#!/usr/bin/python3

import configparser

config = configparser.ConfigParser()
config.read('/etc/designate/designate.conf')

config['service:api']['listen'] = '0.0.0.0:9001'
config['service:api']['auth_strategy'] = 'keystone'
config['service:api']['enable_api_v2'] = 'True'
config['service:api']['enable_api_admin'] = 'True'
config['service:api']['enable_host_header'] = 'True'
config['service:api']['enabled_extensions_admin'] = 'quotas, reports'

config['keystone_authtoken']['auth_type'] = 'password'
config['keystone_authtoken']['username'] = '${DESIGNATE_USER}'
config['keystone_authtoken']['password'] = '${DESIGNATE_PASSWORD}'
config['keystone_authtoken']['project_name'] = 'service'
config['keystone_authtoken']['project_domain_name'] = 'Default'
config['keystone_authtoken']['user_domain_name'] = 'Default'
config['keystone_authtoken']['www_authenticate_uri'] = 'http://${KEYSTONE_HOSTNAME}:5000/'
config['keystone_authtoken']['auth_url'] = 'http://${KEYSTONE_HOSTNAME}:5000/'
config['keystone_authtoken']['memcached_servers'] = '${ADVERTISE_ADDRESS}:11211'

config['storage:sqlalchemy']['connection'] = 'mysql+pymysql://${MARIADB_USER}:${MARIADB_PASSWORD}@${MARIADB_SERVER}/designate'
config['DEFAULT']['transport_url'] = 'rabbit://${RABBITMQ_DEFAULT_USER}:${RABBITMQ_DEFAULT_PASS}@${RABBITMQ_HOSTNAME}:5672/'

with open('/etc/designate/designate.conf', 'w') as configfile:
    config.write(configfile)

EOF

cat > /etc/designate/pools.yaml <<EOF
- name: default
  # The name is immutable. There will be no option to change the name after
  # creation and the only way will to change it will be to delete it
  # (and all zones associated with it) and recreate it.
  description: Default Pool

  attributes: {}

  # List out the NS records for zones hosted within this pool
  # This should be a record that is created outside of designate, that
  # points to the public IP of the controller node.
  ns_records:
    - hostname: ${NAMED_HOSTNAME}.
      priority: 1

  # List out the nameservers for this pool. These are the actual BIND servers.
  # We use these to verify changes have propagated to all nameservers.
  nameservers:
    - host: ${NAMED_ADDRESS}
      port: ${NAMED_DNS_PORT}

  # List out the targets for this pool. For BIND there will be one
  # entry for each BIND server, as we have to run rndc command on each server
  targets:
    - type: bind9
      description: BIND9 Server 1

      # List out the designate-mdns servers from which BIND servers should
      # request zone transfers (AXFRs) from.
      # This should be the IP of the controller node.
      # If you have multiple controllers you can add multiple masters
      # by running designate-mdns on them, and adding them here.
      masters:
        - host: ${ADVERTISE_ADDRESS}
          port: 5354

      # BIND Configuration options
      options:
        host: ${NAMED_ADDRESS}
        port: ${NAMED_DNS_PORT}
        rndc_host: ${NAMED_ADDRESS}
        rndc_port: ${NAMED_RNDC_PORT}
        rndc_key_file: /etc/designate/rndc.key
EOF

chmod +x /usr/local/bin/configure-designate
/usr/local/bin/configure-designate

if [ -z "$(openstack service list | grep dns)" ]; then
  openstack user create --domain default --password ${DESIGNATE_PASSWORD} designate | tee -a /var/log/configure-designate.log
  openstack role add --project service --user designate admin | tee -a /var/log/configure-designate.log
  openstack service create --name designate --description "DNS" dns | tee -a /var/log/configure-designate.log
  openstack endpoint create --region RegionOne dns public http://${ADVERTISE_ADDRESS}:9001/ | tee -a /var/log/configure-designate.log
fi

su -s /bin/sh -c "/usr/local/bin/designate.sh" designate
