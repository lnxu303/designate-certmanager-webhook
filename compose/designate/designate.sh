#!/bin/bash
designate-manage database sync

/etc/init.d/designate-agent systemd-start </dev/null &>/dev/null &
/etc/init.d/designate-api systemd-start </dev/null &>/dev/null &
/etc/init.d/designate-central systemd-start </dev/null &>/dev/null &

sleep 2

designate-manage pool update

/etc/init.d/designate-mdns systemd-start </dev/null &>/dev/null &
/etc/init.d/designate-producer systemd-start </dev/null &>/dev/null &
/etc/init.d/designate-worker systemd-start </dev/null &>/dev/null
