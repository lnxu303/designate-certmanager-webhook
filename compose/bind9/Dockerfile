FROM ubuntu/bind9

RUN export DEBIAN_FRONTEND=noninteractive ; \
	apt update ; \
	apt upgrade -y ; \
	apt install dnsutils -y; \
	mkdir -p /var/log/named ; \
	chown bind:bind /var/log/named

COPY health-check.sh /usr/local/bin/health-check.sh
COPY named.conf.options /etc/bind/named.conf.options