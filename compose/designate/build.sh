#!/bin/bash
CURDIR=$(dirname $0)

docker buildx build --pull --platform linux/amd64,linux/arm64 --push -t fred78290/ubuntu-designate:latest ${CURDIR}
