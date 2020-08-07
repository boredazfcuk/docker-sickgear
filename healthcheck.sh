#!/bin/ash

if [ "$(netstat -plnt | grep -c 8081)" -eq 0 ]; then
   echo "SickGear WebUI not responding on port 8081"
   exit 1
fi

if [ "$(ip -o addr | grep "$(hostname -i)" | wc -l)" -eq 0 ]; then
   echo "NIC missing"
   exit 1
fi

echo "SickGear WebUI responding OK"
exit 0