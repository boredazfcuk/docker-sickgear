#!/bin/ash
wget --quiet --tries=1 --no-check-certificate --spider http://${HOSTNAME}:8081/sickgear/home || exit 1
exit 0