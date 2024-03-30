FROM ubuntu:jammy

RUN export DEBIAN_FRONTEND=noninteractive ; \
	apt update ; \
	apt upgrade -y ; \
	apt install -y python3-openstackclient python3-keystoneclient python3-designateclient \
		python3-novaclient python3-neutronclient python3-glanceclient \
		python3-octaviaclient python3-placement