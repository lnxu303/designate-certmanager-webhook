#!/bin/sh
/usr/bin/dig +short +retry=0 @127.0.0.1 github.com >> /tmp/dig.log || exit 1