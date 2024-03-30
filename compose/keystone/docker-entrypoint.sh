#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

NET_INF=$(ip route get 1|awk '{print $5;exit}')
ADVERTISE_ADDRESS=$(ip addr show ${NET_INF} | grep "inet\s" | tr '/' ' ' | awk '{print $2}')

cat > /usr/local/bin/configure-keystone <<EOF
#!/usr/bin/python3

import configparser

config = configparser.ConfigParser()
config.read('/etc/keystone/keystone.conf')

config['database']['connection'] = 'mysql+pymysql://${MARIADB_USER}:${MARIADB_PASSWORD}@${MARIADB_SERVER}/keystone'
config['token']['provider'] = 'fernet'
with open('/etc/keystone/keystone.conf', 'w') as configfile:
    config.write(configfile)

EOF

chmod +x /usr/local/bin/configure-keystone

/usr/local/bin/configure-keystone

su -s /bin/sh -c "keystone-manage db_sync" keystone
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

echo ServerName ${ADVERTISE_ADDRESS} >> /etc/apache2/sites-available/keystone.conf

keystone-manage bootstrap --bootstrap-password ${MARIADB_PASSWORD} \
	--bootstrap-admin-url http://${ADVERTISE_ADDRESS}:5000/v3/ \
	--bootstrap-internal-url http://${ADVERTISE_ADDRESS}:5000/v3/ \
	--bootstrap-public-url http://${ADVERTISE_ADDRESS}:5000/v3/ \
	--bootstrap-region-id RegionOne

/usr/sbin/apachectl restart

export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=${MARIADB_PASSWORD}
export OS_AUTH_URL=http://${ADVERTISE_ADDRESS}:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2

if [ -z "$(openstack project list | grep demo)" ]; then
	openstack project create --domain default --description "Service Project" service
	openstack project create --domain default --description "Demo Project" demo
	openstack user create --domain default --description "Demo user" --password demo demo
	openstack role add --project demo --user demo member
fi

exec sleep infinity