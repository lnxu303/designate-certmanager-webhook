#!/bin/sh
export DEBIAN_FRONTEND=noninteractive

if [ -n "${RNDC_KEY_B64}" ]; then
	echo -n "${RNDC_KEY_B64}" | base64 -d > /etc/bind/rndc.key
fi

apt update
apt upgrade -y
apt install dnsutils -y

mkdir -p /var/log/named
chown bind:bind /var/log/named

/usr/local/bin/docker-entrypoint.sh $@