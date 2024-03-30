FROM ubuntu:jammy

ENV DESIGNATE_USER=designate
ENV DESIGNATE_PASSWORD=password
ENV KEYSTONE_HOSTNAME=keystone
ENV MARIADB_USER=designate
ENV MARIADB_PASSWORD=password
ENV MARIADB_SERVER=mariadb
ENV RABBITMQ_DEFAULT_USER=rabbitmq
ENV RABBITMQ_DEFAULT_PASS=password
ENV RABBITMQ_HOSTNAME=rabbitmq
ENV NAMED_HOSTNAME=named
ENV NAMED_DNS_PORT=53
ENV NAMED_RNDC_PORT=953
ENV OS_PROJECT_DOMAIN_NAME=Default
ENV OS_USER_DOMAIN_NAME=Default
ENV OS_PROJECT_NAME=admin
ENV OS_USERNAME=admin
ENV OS_PASSWORD=password
ENV OS_AUTH_URL=http://keystone:5000/v3/
ENV OS_IDENTITY_API_VERSION=3
ENV OS_IMAGE_API_VERSION=2

RUN export DEBIAN_FRONTEND=noninteractive ; apt update ; \
	apt upgrade -y ; \
	apt install iproute2 net-tools dnsutils bind9utils designate designate-worker designate-producer designate-mdns -y; \
	apt install -y python3-openstackclient

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY designate.sh /usr/local/bin/designate.sh

EXPOSE 9001

ENTRYPOINT [ "/docker-entrypoint.sh" ]