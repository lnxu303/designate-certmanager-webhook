FROM ubuntu:jammy

ENV MARIADB_USER=keystone
ENV MARIADB_PASSWORD=password
ENV MARIADB_SERVER=mariadb

RUN export DEBIAN_FRONTEND=noninteractive ; \
	apt update ; \
	apt upgrade -y ; \
	apt install iproute2 net-tools keystone -y ; \
	apt install -y python3-openstackclient

COPY docker-entrypoint.sh /docker-entrypoint.sh

EXPOSE 5000

ENTRYPOINT [ "/docker-entrypoint.sh" ]