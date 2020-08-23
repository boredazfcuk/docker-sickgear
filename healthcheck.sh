#!/bin/ash

if [ "$(netstat -plnt | grep -c 8081)" -eq 0 ]; then
   echo "SickGear WebUI not responding on port 8081"
   exit 1
fi

if [ "$(hostname -i 2>/dev/null | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | wc -l)" -eq 0 ]; then
   echo "NIC missing"
   exit 1
fi

echo "SickGear WebUI responding OK"
exit 0