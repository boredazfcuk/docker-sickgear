#!/bin/ash

if [ "$(nc -z "$(hostname -i)" 8081; echo $?)" -ne 0 ]; then
   echo "SickGear WebUI not responding on port 8081"
   exit 1
fi

echo "SickGear WebUI responding OK"
exit 0